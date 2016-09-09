//
//  Cell.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//
import CoreData
public class Cell: NSManagedObject {

	private let group: dispatch_group_t = dispatch_group_create()
	
	private enum Ready {
		case state
		case train
		case delta
	}
	
	private struct Level {
		let φ: Buffer
		let μ: Buffer
		let λ: Buffer
	}
	
	private var ready: Set<Ready> = Set<Ready>()
	
	private var state: RingBuffer<Buffer> = RingBuffer<Buffer>(array: [])
	private var train: RingBuffer<Buffer> = RingBuffer<Buffer>(array: [])
	private var error: RingBuffer<Buffer> = RingBuffer<Buffer>(array: [])
	private var nabla: RingBuffer<Buffer> = RingBuffer<Buffer>(array: [])
	
	private var level: RingBuffer<Level> = RingBuffer<Level>(array: [])
	
	internal var distribution: Distribution = FalseDistribution()
	
}

extension Cell {
	@NSManaged public private(set) var label: String
	@NSManaged public private(set) var width: Int
	@NSManaged public private(set) var attribute: [String: AnyObject]
	@NSManaged public var priority: Int
	@NSManaged public var distributionType: String
	@NSManaged private var input: Set<Edge>
	@NSManaged private var output: Set<Edge>
	@NSManaged private var bias: Bias
	@NSManaged private var circular: Circular?
	@NSManaged private var decay: Decay?
}
extension Cell {
	public var type: DistributionType {
		get {
			return DistributionType(rawValue: distributionType) ?? .False
		}
		set {
			distributionType = newValue.rawValue
		}
	}
}

extension Cell {
	public override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
	public override func awakeFromSnapshotEvents(flags: NSSnapshotEventType) {
		super.awakeFromSnapshotEvents(flags)
		setup()
	}
}

extension Cell {
	public var withDecay: Bool {
		return decay != nil
	}
//	public var withFeedback: Bool {
//		return feedback != nil
//	}
}

extension Cell {
	internal func setup() {
		
		guard let context: Context = managedObjectContext as? Context else { fatalError(Context.Error.InvalidContext.rawValue) }
		
		switch type {
		case .False:
			distribution = FalseDistribution()
		case .Cauchy:
			distribution = try!CauchyDistribution(context: context)
		case .Gauss:
			distribution = try!GaussianDistribution(context: context)
		}
		
		let count: Int = 2
		
		state = RingBuffer<Buffer>(array: (0..<count).map {(_) in context.newBuffer(length: sizeof(Float)*width, options: .StorageModeShared) })
		train = RingBuffer<Buffer>(array: (0..<count).map {(_) in context.newBuffer(length: sizeof(Float)*width, options: .StorageModeShared) })
		error = RingBuffer<Buffer>(array: (0..<count).map {(_) in context.newBuffer(length: sizeof(Float)*width, options: .StorageModeShared) })
		nabla = RingBuffer<Buffer>(array: (0..<count).map {(_) in context.newBuffer(length: sizeof(Float)*width, options: .StorageModeShared) })
		level = RingBuffer<Level>(array: (0..<count).map {(_) in Level(
			φ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModeShared),
			μ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModeShared),
			λ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModeShared))
		})
	}
}
extension Cell {
	public func collect_clear() {
		if ready.contains(.state) {
			
			ready.remove(.state)
			
			if let context: Context = managedObjectContext as? Context {
				
				let command: Command = context.newCommand()
				let compute: Compute = command.computeCommandEncoder()
				
				enter()
				func complete(command: Command) { leave() }
				
				input.forEach { $0.collect_clear( compute ) }
				bias.collect_clear(compute)
				
				compute.endEncoding()
				command.addCompletedHandler(complete)
				command.commit()
				
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
			
			train.progress()
			state.progress()
			level.progress()
			
		}
	}
	public func correct_clear() {
		
		if ready.contains(.delta) {
			
			ready.remove(.delta)
			
			output.forEach { $0.correct_clear() }
			
			bias.correct_clear()
			
			nabla.progress()
			
		}
		
		ready.remove(.train)
	}
	public func collect(ignore: Set<Cell>=[]) -> LaObjet {
		if ignore.contains(self) {
			return _χ
			
		} else {
			if !ready.contains(.state) {
				
				let refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)] = input.map { $0.collect(ignore.union([self])) } + [ bias.collect() ]
					
				merge()
				distribution.synthesize(χ: level.new.φ, μ: level.new.μ, λ: level.new.λ, refer: refer)//cpu
				
				if let context: Context = managedObjectContext as? Context {
					
					let command: Command = context.newCommand()
					let compute: Compute = command.computeCommandEncoder()
				
					enter()
					func complete(command: Command) { leave() }
				
					distribution.pdf(compute, χ: nabla.new, μ: level.new.μ, λ: level.new.λ)//gpu
					
					compute.endEncoding()
					command.addCompletedHandler(complete)
					command.commit()
					
				} else {
					assertionFailure(Context.Error.InvalidContext.rawValue)
					
				}
				step(y: state.new, x: level.new.φ)
				ready.insert(.state)
			}
			return χ
		}
	}
	internal func correct(ignore: Set<Cell>=[]) -> (Δ: LaObjet, gradμ: LaObjet, gradσ: LaObjet) {
		if ignore.contains(self) {
			return (_Δ, _ϝ, -1 * _ϝ * _μ * _λ)
			
		} else {
			if !ready.contains(.delta) {
				
				let δ: LaObjet = ready.contains(.train) ? χ - ψ : output.map { $0.correct(ignore.union([self])) } .reduce(LaValuer(0)) { $0.0 + $0.1 }
				δ.getBytes(error.new.bytes)//cpu
				
				sign(y: error.new, x: error.new)
				ready.insert(.delta)
				
				bias.correct(ignore)//cpu
				
			}
			merge()
			return (Δ, ϝ, -1 * ϝ * μ * λ)
		}
	}
	internal func chain(x: LaObjet) -> LaObjet {
		return LaValuer(0)
	}
}
extension Cell {
	func enter() {
		dispatch_group_enter(group)
	}
	func leave() {
		dispatch_group_leave(group)
	}
	func merge() {
		dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
	}
}
extension Cell {
	
	internal var χ: LaObjet { return LaMatrice(state.new.bytes, rows: width, cols: 1, deallocator: nil) }
	internal var ψ: LaObjet { return LaMatrice(train.new.bytes, rows: width, cols: 1, deallocator: nil) }
	internal var Δ: LaObjet { return LaMatrice(error.new.bytes, rows: width, cols: 1, deallocator: nil) }
	internal var ϝ: LaObjet { return LaMatrice(nabla.new.bytes, rows: width, cols: 1, deallocator: nil) }
	
	internal var _χ: LaObjet { return LaMatrice(state.old.bytes, rows: width, cols: 1, deallocator: nil) }
	internal var _ψ: LaObjet { return LaMatrice(train.old.bytes, rows: width, cols: 1, deallocator: nil) }
	internal var _Δ: LaObjet { return LaMatrice(error.old.bytes, rows: width, cols: 1, deallocator: nil) }
	internal var _ϝ: LaObjet { return LaMatrice(nabla.old.bytes, rows: width, cols: 1, deallocator: nil) }
	
	internal var φ: LaObjet { return LaMatrice(level.new.φ.bytes, rows: width, cols: 1, deallocator: nil) }
	internal var μ: LaObjet { return LaMatrice(level.new.μ.bytes, rows: width, cols: 1, deallocator: nil) }
	internal var λ: LaObjet { return LaMatrice(level.new.λ.bytes, rows: width, cols: 1, deallocator: nil) }

	internal var _φ: LaObjet { return LaMatrice(level.old.φ.bytes, rows: width, cols: 1, deallocator: nil) }
	internal var _μ: LaObjet { return LaMatrice(level.old.μ.bytes, rows: width, cols: 1, deallocator: nil) }
	internal var _λ: LaObjet { return LaMatrice(level.old.λ.bytes, rows: width, cols: 1, deallocator: nil) }

}
extension Cell {
	public var active: [Bool] {
		set {
			if 0 < width {
				var ref: [Float] = newValue.map { Float($0) }
				Data(bytesNoCopy: &ref, length: sizeof(Float)*ref.count, freeWhenDone: false).getBytes(state.new.bytes, length: state.new.length)
				ready.insert(.state)
			}
		}
		get {
			collect()
			return 0 < width ? UnsafeMutableBufferPointer<Float>(start: state.new.bytes, count: state.new.length/sizeof(Float)) .map { Bool($0) } : []
		}
	}
	public var answer: [Bool] {
		set {
			if 0 < width {
				var ref: [Float] = newValue.map { Float($0) }
				Data(bytesNoCopy: &ref, length: sizeof(Float)*ref.count, freeWhenDone: false).getBytes(train.new.bytes, length: train.new.length)
				ready.insert(.train)
			}
		}
		get {
			return 0 < width ? UnsafeMutableBufferPointer<Float>(start: train.new.bytes, count: train.new.length/sizeof(Float)) .map { Bool($0) } : []
		}
	}
	public var isRecurrent: Bool {
		return circular != nil || decay != nil
	}
}
extension Context {
	public func newCell (type: DistributionType, width: Int, label: String = "", recur: Bool = false, buffer: Bool = false, input: [Cell] = [] ) throws -> Cell {
		guard let cell: Cell = new() else {
			throw Error.CoreData.InsertionFails(entity: Cell.self)
		}
		cell.label = label
		cell.width = width
		cell.type = type
		cell.attribute = [:]
		cell.input = Set<Edge>()
		cell.output = Set<Edge>()
		cell.setup()
		try input.forEach {
			try newEdge(output: cell, input: $0)
		}
		try newBias(output: cell)
		return cell
	}
	public func searchCell( let width width: Int? = nil, let label: String? = nil ) -> [Cell] {
		var attribute: [String: AnyObject] = [:]
		if let width: Int = width {
			attribute [ "width" ] = width
		}
		if let label: String = label {
			attribute [ "label" ] = label
		}
		return fetch ( attribute )
	}
	public func chainCell(let output output: Cell, let input: Cell) throws {
		let contains: Bool = output.input.map { $0 === input } .reduce(false) { $0.0 || $0.1 }
		if !contains {
			try newEdge(output: output, input: input)
		}
	}
	/*
	public func unchainCell(let output output: Cell, let input: Cell) {
		output.input.filter{ $0.input === input }.forEach {
			deleteObject($0)
		}
	}
	*/
}