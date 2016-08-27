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

public class Cell: NSManagedObject {
	
	private enum Ready {
		case ψ
		case ϰ
		case δ
	}
	
	private var ready: Set<Ready> = Set<Ready>()
	
	private struct Deterministic {
		let ψ: [Float]
		let ϰ: [Float]
		let δ: [Float]
	}
	
	private struct Probabilistic {
		let χ: [Float]
		let μ: [Float]
		let σ: [Float]
	}
	
	private var Υ: RingBuffer<Deterministic> = RingBuffer<Deterministic>(array: [])
	private var Φ: RingBuffer<Probabilistic> = RingBuffer<Probabilistic>(array: [])
	private var Δ: RingBuffer<Probabilistic> = RingBuffer<Probabilistic>(array: [])
	
}

extension Cell {
	@NSManaged public private(set) var label: String
	@NSManaged public private(set) var width: Int
	@NSManaged public private(set) var attribute: [String: AnyObject]
	@NSManaged public var priority: Int
	@NSManaged private var input: Set<Edge>
	@NSManaged private var output: Set<Edge>
	@NSManaged private var bias: Bias
	@NSManaged private var feedback: Feedback?
	@NSManaged private var decay: Decay?
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
		Υ = RingBuffer<Deterministic>(array: (0..<count).map{(_)in
			return Deterministic(
				ψ: [Float](count: width, repeatedValue: 0),
				ϰ: [Float](count: width, repeatedValue: 0),
				δ: [Float](count: width, repeatedValue: 0)
			)
		})
		Φ = RingBuffer<Probabilistic>(array: (0..<count).map{(_)in
			return Probabilistic(
				χ: [Float](count: width, repeatedValue: 0),
				μ: [Float](count: width, repeatedValue: 0),
				σ: [Float](count: width, repeatedValue: 0)
			)
		})
		Δ = RingBuffer<Probabilistic>(array: (0..<count).map{(_)in
			return Probabilistic(
				χ: [Float](count: width, repeatedValue: 0),
				μ: [Float](count: width, repeatedValue: 0),
				σ: [Float](count: width, repeatedValue: 0)
			)
		})
		iRefresh()
		oRefresh()
	}
}
extension Cell {
	internal func iRefresh() {
		Υ.progress()
		Φ.progress()
		bias.shuffle()
	}
	private func oRefresh() {
		Δ.progress()
		bias.refresh()
	}
	
	public func iClear() {
		if ready.contains(.ϰ) {
			ready.remove(.ϰ)
			input.forEach {
				$0.iClear()
			}
			iRefresh()
		}
	}
	
	public func oClear() {
		if ready.contains(.δ) {
			ready.remove(.δ)
			output.forEach {
				$0.oClear()
			}
			oRefresh()
		}
		ready.remove(.ψ)
	}
	
	public func collect(let ignore: Set<Cell> = []) -> la_object_t {
		if ignore.contains(self) {
			return la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(Υ.old.ϰ), la_count_t(width), la_count_t(1), la_count_t(1), Config.NOHINT, nil, Config.ATTR)
		} else if !ready.contains(.ϰ) {
			ready.insert(.ϰ)
			var level: (χ: la_object_t, μ: la_object_t, σ: la_object_t) = bias.collect()
			input.forEach {
				let c: (χ: la_object_t, μ: la_object_t, σ: la_object_t) = $0.collect(ignore.union([self]))
				level.χ = level.χ + c.χ
				level.μ = level.μ + c.μ
				level.σ = level.σ + c.σ
			}
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(Φ.new.χ), la_count_t(1), level.χ)
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(Φ.new.μ), la_count_t(1), level.μ)
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(Φ.new.σ), la_count_t(1), level.σ)
			
		}
		return la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(Υ.new.ϰ), la_count_t(width), la_count_t(1), la_count_t(1), Config.NOHINT, nil, Config.ATTR)
	}
	
	public func correct(let η η: Float, let ignore: Set<Cell>=[]) -> (la_object_t, la_object_t, la_object_t) {
		if ignore.contains(self) {
			return(
				la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(Δ.old.χ), la_count_t(width), la_count_t(1), la_count_t(1), Config.NOHINT, nil, Config.ATTR),
				la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(Δ.old.μ), la_count_t(width), la_count_t(1), la_count_t(1), Config.NOHINT, nil, Config.ATTR),
				la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(Δ.old.σ), la_count_t(width), la_count_t(1), la_count_t(1), Config.NOHINT, nil, Config.ATTR)
			)
		} else if !ready.contains(.δ) {
			ready.insert(.δ)
			var error: la_object_t = la_splat_from_float(0, Config.ATTR)
			if ready.contains(.ψ) {
				let src: la_object_t = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(Υ.new.ϰ), la_count_t(width), la_count_t(1), la_count_t(1), Config.NOHINT, nil, Config.ATTR)
				let dst: la_object_t = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(Υ.new.ψ), la_count_t(width), la_count_t(1), la_count_t(1), Config.NOHINT, nil, Config.ATTR)
				error = la_difference(dst, src)
			} else {
				
			}
		}
		return(
			la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(Δ.new.χ), la_count_t(width), la_count_t(1), la_count_t(1), Config.NOHINT, nil, Config.ATTR),
			la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(Δ.new.μ), la_count_t(width), la_count_t(1), la_count_t(1), Config.NOHINT, nil, Config.ATTR),
			la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(Δ.new.σ), la_count_t(width), la_count_t(1), la_count_t(1), Config.NOHINT, nil, Config.ATTR)
		)
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
	public func newCell ( let width width: Int, let label: String = "", let recur: Bool = false, let buffer: Bool = false, let input: [Cell] = [] ) throws -> Cell {
		guard let cell: Cell = new() else {
			throw Error.CoreData.InsertionFails(entity: Cell.className())
		}
		cell.label = label
		cell.width = ((width-1)/4+1)*4
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