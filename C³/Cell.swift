//
//  Cell.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import Accelerate
import Metal
import CoreData

internal protocol Chainable {
	func collect(ignore: Set<Cell>) -> (LaObjet, LaObjet, LaObjet)
	func correct(ignore: Set<Cell>) -> LaObjet
	func collect_clear(distribution: Distribution.Type)
	func correct_clear()
}

public class Cell: NSManagedObject {
	
	private enum Ready {
		case ψ
		case ϰ
		case δ
	}
	
	private var ready: Set<Ready> = Set<Ready>()
	private var group: dispatch_group_t = dispatch_group_create()
	
	private struct Deterministic {
		let ψ: MTLBuffer
		let ϰ: MTLBuffer
		let δ: MTLBuffer
	}
	
	private struct deterministic {
		let ψ: [Float]
		let ϰ: [Float]
		let δ: [Float]
	}
	
	private struct Probabilistic {
		let χ: MTLBuffer
		let μ: MTLBuffer
		let σ: MTLBuffer
	}
	
	private struct probabilistic {
		let χ: [Float]
		let μ: [Float]
		let σ: [Float]
	}
	
	private var state: RingBuffer<deterministic> = RingBuffer<deterministic>(array: [])
	private var level: RingBuffer<probabilistic> = RingBuffer<probabilistic>(array: [])
	private var delta: RingBuffer<probabilistic> = RingBuffer<probabilistic>(array: [])
	
	private var Υ: RingBuffer<Deterministic> = RingBuffer<Deterministic>(array: [])
	private var Φ: RingBuffer<Probabilistic> = RingBuffer<Probabilistic>(array: [])
	private var Δ: RingBuffer<Probabilistic> = RingBuffer<Probabilistic>(array: [])
	
}

extension Cell {
	@NSManaged public private(set) var label: String
	@NSManaged public private(set) var width: Int
	@NSManaged public private(set) var attribute: [String: AnyObject]
	@NSManaged public var priority: Int
	@NSManaged private var distributionType: String
	@NSManaged private var input: Set<Edge>
	@NSManaged private var output: Set<Edge>
	@NSManaged private var bias: Bias
	@NSManaged private var feedback: Feedback?
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
	internal var distribution: Distribution.Type {
		switch type {
		case .Gauss:
			return GaussianDistribution.self
		case .Cauchy:
			return CauchyDistribution.self
		case .False:
			return FalseDistribution.self
		}
	}
}

extension Cell {
	public override func awakeFromFetch() {
		super.awakeFromFetch()
		if let context: Context = managedObjectContext as? Context {
			setup(context)
		}  else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		}
	}
	public override func awakeFromSnapshotEvents(flags: NSSnapshotEventType) {
		super.awakeFromSnapshotEvents(flags)
		if let context: Context = managedObjectContext as? Context {
			setup(context)
		}  else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		}
	}
}

extension Cell {
	public var withDecay: Bool {
		return decay != nil
	}
	public var withFeedback: Bool {
		return feedback != nil
	}
}

extension Cell {
	internal func setup(let context: Context) {
		let count: Int = 2
		state = RingBuffer<deterministic>(array: (0..<count).map{(_)in
			deterministic(
				ψ: [Float](count: width, repeatedValue: 0),
				ϰ: [Float](count: width, repeatedValue: 0),
				δ: [Float](count: width, repeatedValue: 0)
			)
		})
		level = RingBuffer<probabilistic>(array: (0..<count).map{(_)in
			probabilistic(
				χ: [Float](count: width, repeatedValue: 0),
				μ: [Float](count: width, repeatedValue: 0),
				σ: [Float](count: width, repeatedValue: 0)
			)
		})
		delta = RingBuffer<probabilistic>(array: (0..<count).map{(_)in
			probabilistic(
				χ: [Float](count: width, repeatedValue: 0),
				μ: [Float](count: width, repeatedValue: 0),
				σ: [Float](count: width, repeatedValue: 0)
			)
		})
		
		Υ = RingBuffer<Deterministic>(array: (0..<count).map{(_)in
			return Deterministic(
				ψ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
				ϰ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
				δ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
			)
		})
		Φ = RingBuffer<Probabilistic>(array: (0..<count).map{(_)in
			return Probabilistic(
				χ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
				μ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
				σ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
			)
		})
		Δ = RingBuffer<Probabilistic>(array: (0..<count).map{(_)in
			return Probabilistic(
				χ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
				μ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
				σ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
			)
		})
		iRefresh()
		oRefresh()
	}
}
extension Cell {
	internal func iRefresh() {
		
		state.progress()
		level.progress()
		
		if let context: Context = managedObjectContext as? Context where 0 < width {
			
			Υ.progress()
			
			let ψ: MTLBuffer = Υ.new.ψ
			let ϰ: MTLBuffer = Υ.new.ϰ
			let δ: MTLBuffer = Υ.new.δ
			
			Φ.progress()
			
			let χ: MTLBuffer = Φ.new.χ
			let μ: MTLBuffer = Φ.new.μ
			let σ: MTLBuffer = Φ.new.σ

			context.newBlitCommand {
				
				$0.fillBuffer(ψ, range: NSRange(location: 0, length: ψ.length), value: 0)
				$0.fillBuffer(ϰ, range: NSRange(location: 0, length: ϰ.length), value: 0)
				$0.fillBuffer(δ, range: NSRange(location: 0, length: δ.length), value: 0)
				
				$0.fillBuffer(χ, range: NSRange(location: 0, length: χ.length), value: 0)
				$0.fillBuffer(μ, range: NSRange(location: 0, length: μ.length), value: 0)
				$0.fillBuffer(σ, range: NSRange(location: 0, length: σ.length), value: 0)
				
			}
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		
		}
		
	}
	private func oRefresh() {
		
		delta.progress()
		
		if let context: Context = managedObjectContext as? Context where 0 < width {
			
			Δ.progress()
			
			let χ: MTLBuffer = Δ.new.χ
			let μ: MTLBuffer = Δ.new.μ
			let σ: MTLBuffer = Δ.new.σ
			
			context.newBlitCommand {
				$0.fillBuffer(χ, range: NSRange(location: 0, length: χ.length), value: 0)
				$0.fillBuffer(μ, range: NSRange(location: 0, length: μ.length), value: 0)
				$0.fillBuffer(σ, range: NSRange(location: 0, length: σ.length), value: 0)
			}
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		
		}
	}
	public func collect_clear() {
		if ready.contains(.ϰ) {
			ready.remove(.ϰ)
			input.forEach {
				$0.collect_clear(distribution)
			}
			iRefresh()
			bias.shuffle(distribution)
		}
	}
	
	public func correct_clear() {
		if ready.contains(.δ) {
			ready.remove(.δ)
			output.forEach {
				$0.correct_clear()
			}
			oRefresh()
		}
		ready.remove(.ψ)
	}
	public func collect(ignore: Set<Cell> = []) -> LaObjet {
		if ignore.contains(self) {
			return LaMatrice(state.old.ϰ, rows: width, cols: 1, deallocator: nil)
		} else {
			if !ready.contains(.ϰ) {
				ready.insert(.ϰ)
				let sum: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)] = input.map { $0.collect(ignore) } + [bias.collect(ignore)]
				let mix: (χ: LaObjet, μ: LaObjet, σ: LaObjet) = distribution.mix(sum)
				mix.χ.getBytes(level.new.χ)
				mix.μ.getBytes(level.new.μ)
				mix.σ.getBytes(level.new.σ)
				self.dynamicType.activate(state.new.ϰ, level: level.new.χ)
			}
			return LaMatrice(state.new.ϰ, rows: width, cols: 1, deallocator: nil)
		}
	}
	public func correct(ignore: Set<Cell> = []) -> (LaObjet, LaObjet, LaObjet) {
		if ignore.contains(self) {
			return (
				LaMatrice(delta.old.χ, rows: width, cols: 1),
				LaMatrice(delta.old.μ, rows: width, cols: 1),
				LaMatrice(delta.old.σ, rows: width, cols: 1)
			)
		} else {
			if ready.contains(.ψ) {
				if !ready.contains(.δ) {
					
				} else {
					
				}
			}
			return (
				LaMatrice(delta.new.χ, rows: width, cols: 1),
				LaMatrice(delta.new.μ, rows: width, cols: 1),
				LaMatrice(delta.new.σ, rows: width, cols: 1)
			)
		}
	}
	
	
	public func collect_mtl(let ignore: Set<Cell> = []) -> MTLBuffer {
		
		return Υ.new.ϰ
	}
	
	public func correct_mtl(let η η: Float, let ignore: Set<Cell>=[]) -> (MTLBuffer, MTLBuffer, MTLBuffer) {
		
		return(Δ.new.χ, Δ.new.μ, Δ.new.σ)
	}
}
extension Cell {
	public var active: [Bool] {
		set {
			if let context: Context = managedObjectContext as? Context {
				let cache: MTLBuffer = context.newBuffer((0..<width).map{$0<newValue.count ? newValue[$0] ? 1:0:0}, options: .StorageModePrivate)
				let value: MTLBuffer = Υ.new.ϰ
				let size: Int = sizeof(Float) * width
				
				assert(size==cache.length)
				assert(size==value.length)
				
				context.newBlitCommand(complete: { cache.setPurgeableState(.Empty) }) {
					$0.copyFromBuffer(cache, sourceOffset: 0, toBuffer: value, destinationOffset: 0, size: size)
				}
				ready.insert(.ϰ)
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
		}
		get {
			collect()
			if let context: Context = managedObjectContext as? Context {
				let cache: MTLBuffer = context.newBuffer(length: sizeof(Float)*width, options: .CPUCacheModeDefaultCache)
				let value: MTLBuffer = Υ.new.ϰ
				let size: Int = sizeof(Float) * width
				
				assert(size==cache.length)
				assert(size==value.length)
				
				context.newBlitCommand(sync: true) {
					$0.copyFromBuffer(value, sourceOffset: 0, toBuffer: cache, destinationOffset: 0, size: size)
				}
				UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(cache.contents()), count: width).forEach {
					assert(!isnan($0))
					assert(!isinf($0))
				}
				defer { cache.setPurgeableState(.Empty) }
				return UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(cache.contents()), count: width).map{Bool($0)}
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
			return [Bool](count: width, repeatedValue: false)
		}
	}
	public var answer: [Bool] {
		set {
			if let context: Context = managedObjectContext as? Context {
				let cache: MTLBuffer = context.newBuffer((0..<width).map{$0<newValue.count ? newValue[$0] ? 1:0:0}, options: .StorageModePrivate)
				let train: MTLBuffer = Υ.new.ψ
				let size: Int = sizeof(Float) * width
				
				assert(size==cache.length)
				assert(size==train.length)
				
				context.newBlitCommand(complete: { cache.setPurgeableState(.Empty) }) {
					$0.copyFromBuffer(cache, sourceOffset: 0, toBuffer: train, destinationOffset: 0, size: size)
				}
				ready.insert(.ψ)
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
		}
		get {
			if let context: Context = managedObjectContext as? Context {
				let cache: MTLBuffer = context.newBuffer(length: sizeof(Float)*width, options: .CPUCacheModeDefaultCache)
				let train: MTLBuffer = Υ.new.ψ
				let size: Int = sizeof(Float) * width
				
				assert(size==cache.length)
				assert(size==train.length)
				
				context.newBlitCommand(sync: true) {
					$0.copyFromBuffer(train, sourceOffset: 0, toBuffer: cache, destinationOffset: 0, size: size)
				}
				UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(cache.contents()), count: width).forEach {
					assert(!isnan($0))
					assert(!isinf($0))
				}
				defer { cache.setPurgeableState(.Empty) }
				return UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(cache.contents()), count: width).map{Bool($0)}
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
			return [Bool](count: width, repeatedValue: false)
		}
	}
	public var isRecurrent: Bool {
		return feedback != nil || decay != nil
	}
}
extension Cell {
	internal class var differenceKernel: String { return "cellDifference" }
	internal class var activateKernel: String { return "cellActivate" }
	internal class var derivateKernel: String { return "cellDerivate" }
	internal static func activate(state: [Float], level: [Float]) {
		assert(state.count==level.count)
		let length: vDSP_Length = vDSP_Length(min(state.count, level.count))
		vDSP_vneg(level, 1, UnsafeMutablePointer<Float>(state), 1, length)
		vDSP_vthrsc(state, 1, [Float(0.0)], [Float(0.5)], UnsafeMutablePointer<Float>(state), 1, length)
		vDSP_vneg(state, 1, UnsafeMutablePointer<Float>(state), 1, length)
		vDSP_vsadd(state, 1, [Float(0.5)], UnsafeMutablePointer<Float>(state), 1, length)
	}
	internal static func derivate(delta: [Float], error: [Float]) {
		assert(delta.count==error.count)
		let length: vDSP_Length = vDSP_Length(min(delta.count, error.count))
		let cache: [Float] = [Float](count: Int(length), repeatedValue: 0)
		vDSP_vthrsc(error, 1, [Float(0.0)], [Float( 0.5)], UnsafeMutablePointer<Float>(delta), 1, length)
		vDSP_vneg(error, 1, UnsafeMutablePointer<Float>(cache), 1, length)
		vDSP_vthrsc(UnsafeMutablePointer<Float>(cache), 1, [Float(0.0)], [Float(-0.5)], UnsafeMutablePointer<Float>(cache), 1, length)
		vDSP_vadd(UnsafeMutablePointer<Float>(cache), 1, UnsafeMutablePointer<Float>(delta), 1, UnsafeMutablePointer<Float>(delta), 1, length)
	}
	internal static func difference(let context context: Context, let δ: MTLBuffer, let ψ: MTLBuffer, let ϰ: MTLBuffer, let width: Int) {
		context.newComputeCommand(function: differenceKernel) {
			$0.setBuffer(δ, offset: 0, atIndex: 0)
			$0.setBuffer(ψ, offset: 0, atIndex: 1)
			$0.setBuffer(ϰ, offset: 0, atIndex: 2)
			$0.dispatchThreadgroups(MTLSize(width: width/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func activate(let context context: Context, let Υ: MTLBuffer, let Φ: MTLBuffer, let width: Int) {
		context.newComputeCommand(function: activateKernel) {
			$0.setBuffer(Υ, offset: 0, atIndex: 0)
			$0.setBuffer(Φ, offset: 0, atIndex: 1)
			$0.dispatchThreadgroups(MTLSize(width: width/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func derivate(let context context: Context, let Δ: (MTLBuffer, MTLBuffer, MTLBuffer), let Φ: (MTLBuffer, MTLBuffer, MTLBuffer), let δ: MTLBuffer, let width: Int) {
		context.newComputeCommand(function: derivateKernel) {
			$0.setBuffer(Δ.0, offset: 0, atIndex: 0)
			$0.setBuffer(Δ.1, offset: 0, atIndex: 1)
			$0.setBuffer(Δ.2, offset: 0, atIndex: 2)
			$0.setBuffer(Φ.0, offset: 0, atIndex: 3)
			$0.setBuffer(Φ.1, offset: 0, atIndex: 4)
			$0.setBuffer(Φ.2, offset: 0, atIndex: 5)
			$0.setBuffer(δ, offset: 0, atIndex: 6)
			$0.setBytes([Float(M_PI)], length: sizeof(Float), atIndex: 7)
			$0.dispatchThreadgroups(MTLSize(width: width/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func forget(let context context: Context, let error: MTLBuffer, let λ: Float, let width: Int) {
		context.newComputeCommand(function: "cellForget") {
			$0.setBuffer(error, offset: 0, atIndex: 0)
			$0.setBytes([λ], length: sizeof(Float), atIndex: 1)
			$0.dispatchThreadgroups(MTLSize(width: width/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
}
extension Context {
	public func newCell (type: DistributionType, width: Int, label: String = "", recur: Bool = false, buffer: Bool = false, input: [Cell] = [] ) throws -> Cell {
		guard let cell: Cell = new() else {
			throw Error.CoreData.InsertionFails(entity: Cell.className())
		}
		cell.label = label
		cell.width = width
		cell.type = type
		cell.attribute = [:]
		cell.input = Set<Edge>()
		cell.output = Set<Edge>()
		cell.setup(self)
		try input.forEach {
			try newEdge(output: cell, input: $0)
		}
		try newBias(output: cell)
		return cell
	}
	public func searchCell( let width width: Int? = nil, let label: String? = nil ) -> [Cell] {
		var attribute: [String: AnyObject] = [:]
		if let width: Int = width {
			attribute [ "width" ] = ((width-1)/4+1)*4
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