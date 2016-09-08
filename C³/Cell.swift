//
//  Cell.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import CoreData
public class Cell: NSManagedObject {

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
	
	internal private(set) var distribution: Distribution = FalseDistribution()
	
	private var activate: Pipeline?
	private var derivate: Pipeline?
	
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
		guard let context: Context = managedObjectContext as? Context else {
			fatalError(Context.Error.InvalidContext.rawValue)
		}
		activate = try?context.newPipeline("cellActivate")
		derivate = try?context.newPipeline("cellDerivate")
		switch type {
		case .False:
			distribution = FalseDistribution()
		case .Cauchy:
			distribution = try!CauchyDistribution(context: context)
		case .Gauss:
			distribution = try!GaussianDistribution(context: context)
		}
		print(distribution)
		let count: Int = 2
		
		state = RingBuffer<Buffer>(array: (0..<count).map {(_)in
			context.newBuffer(length: sizeof(Float)*width, options: .StorageModeShared)
		})
		train = RingBuffer<Buffer>(array: (0..<count).map {(_)in
			context.newBuffer(length: sizeof(Float)*width, options: .StorageModeShared)
		})
		error = RingBuffer<Buffer>(array: (0..<count).map {(_)in
			context.newBuffer(length: sizeof(Float)*width, options: .StorageModeShared)
		})
		nabla = RingBuffer<Buffer>(array: (0..<count).map {(_)in
			context.newBuffer(length: sizeof(Float)*width, options: .StorageModeShared)
		})
		level = RingBuffer<Level>(array: (0..<count).map {(_)in
			Level(
				φ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModeShared),
				μ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModeShared),
				λ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModeShared)
			)
		})
	}
}
extension Cell {
	public func collect_clear() {
		if ready.contains(.state) {
			ready.remove(.state)
			
			guard let context: Context = managedObjectContext as? Context else {
				assertionFailure()
				return
			}
			let command: Command = context.newCommand()
			let compute: Compute = command.computeCommandEncoder()

			input.forEach {
				$0.collect_clear(compute)
			}
			bias.collect_clear(compute)
			
			train.progress()
			state.progress()
			level.progress()
			
			compute.endEncoding()
			command.commit()
		}
	}
	public func correct_clear() {
		if ready.contains(.delta) {
			ready.remove(.delta)
			output.forEach {
				$0.correct_clear()
			}
			bias.correct_clear()
			nabla.progress()
		}
		ready.remove(.train)
	}
	public func collect() {
		guard let context: Context = managedObjectContext as? Context else {
			fatalError(Context.Error.InvalidContext.rawValue)
		}
		let command: Command = context.newCommand()
		let compute: Compute = command.computeCommandEncoder()
		collect(compute: compute, ignore: [])
		compute.endEncoding()
		command.commit()
		command.waitUntilCompleted()
	}
	internal func collect(compute parent: Compute, ignore: Set<Cell>) -> LaObjet {
		if ignore.contains(self) {
			return _χ
		} else {
			if !ready.contains(.state) {
				
				guard let context: Context = managedObjectContext as? Context else {
					fatalError(Context.Error.InvalidContext.rawValue)
				}
				
				let command: Command = context.newCommand()
				let compute: Compute = command.computeCommandEncoder()
				
				let refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)] = input.map { $0.collect(context, compute: compute, ignore: ignore.union([self])) } + [ bias.collect() ]
				
				compute.endEncoding()
				command.commit()
				command.waitUntilCompleted()
				
				distribution.synthesize(χ: level.new.φ, μ: level.new.μ, λ: level.new.λ, refer: refer)
				
				if let activate: Pipeline = activate {
					parent.setComputePipelineState(activate)
					parent.setBuffer(state.new, offset: 0, atIndex: 0)
					parent.setBuffer(level.new.φ, offset: 0, atIndex: 1)
					parent.dispatch(grid: ((width+3)/4, 1, 1), threads: (1, 1, 1))
				} else {
					let yref: UnsafeMutablePointer<Float> = state.new.bytes
					let xref: UnsafeMutablePointer<Float> = level.new.φ.bytes
					for k in 0..<width {
						yref[k] = 0 < xref[k] ? 1 : 0
					}
					assertionFailure()
				}
				
				ready.insert(.state)
			}
			return χ
		}
	}
	public func correct() {
		guard let context: Context = managedObjectContext as? Context else {
			fatalError(Context.Error.InvalidContext.rawValue)
		}
		let command: Command = context.newCommand()
		let compute: Compute = command.computeCommandEncoder()
		correct(compute: compute, ignore: [])
		compute.endEncoding()
		command.commit()
		command.waitUntilCompleted()
	}
	internal func correct(compute child: Compute, ignore: Set<Cell>) -> (LaObjet, LaObjet, LaObjet) {
		if ignore.contains(self) {
			return (_Δ, _ϝ, -1 * _ϝ * _μ * _λ)
		} else {
			if !ready.contains(.delta) {
				
				guard let context: Context = managedObjectContext as? Context else {
					fatalError(Context.Error.InvalidContext.rawValue)
				}
				
				let command: Command = context.newCommand()
				let compute: Compute = command.computeCommandEncoder()
				
				let δ: LaObjet = ready.contains(.train) ? χ - ψ : output.map { $0.correct(compute, ignore: ignore.union([self])) } .reduce(LaValuer(0)) { $0.0 + $0.1 }
				
				compute.endEncoding()
				command.commit()
				command.waitUntilCompleted()
				
				δ.getBytes(error.new.bytes)
				
				if let derivate: Pipeline = derivate {
					child.setComputePipelineState(derivate)
					child.setBuffer(error.new, offset: 0, atIndex: 0)
					child.setBuffer(error.new, offset: 0, atIndex: 1)
					child.dispatch(grid: ((width+3)/4, 1, 1), threads: (1, 1, 1))
				} else {
					assertionFailure()
				}
				distribution.pdf(child, χ: nabla.new, μ: level.new.μ, λ: level.new.λ)
				
				ready.insert(.delta)
				do {
					let command: Command = context.newCommand()
					let compute: Compute = command.computeCommandEncoder()
					bias.correct(compute, ignore: ignore)
					compute.endEncoding()
					command.commit()
				}
			}
			return (Δ, ϝ, -1 * ϝ * μ * λ)
		}
	}
	internal func chain(x: LaObjet) -> LaObjet {
		return LaValuer(0)
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