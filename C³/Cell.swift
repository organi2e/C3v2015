
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
		case State
		case Delta
		case Train
	}
	private var ready: Set<Ready> = Set<Ready>()
	
	private struct State {
		let train: MTLBuffer
		let value: MTLBuffer
		let error: MTLBuffer
	}
	
	private struct Level {
		let value: MTLBuffer
		let mu: MTLBuffer
		let sigma: MTLBuffer
	}
	
	private struct Delta {
		let value: MTLBuffer
		let mu: MTLBuffer
		let sigma: MTLBuffer
	}
	
	private var states: RingBuffer<State> = RingBuffer<State>(array: [])
	private var levels: RingBuffer<Level> = RingBuffer<Level>(array: [])
	private var deltas: RingBuffer<Delta> = RingBuffer<Delta>(array: [])
	
}

extension Cell {
	@NSManaged public private(set) var label: String
	@NSManaged public private(set) var width: Int
	@NSManaged public private(set) var attribute: [String: AnyObject]
	@NSManaged private var input: Set<Edge>
	@NSManaged private var output: Set<Edge>
	@NSManaged private var bias: Bias
	@NSManaged private var feedback: Feedback?
	@NSManaged private var decay: Decay?
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
	public var withFeedback: Bool {
		return feedback != nil
	}
}

extension Cell {
	internal func setup() {
		
		if let context: Context = managedObjectContext as? Context {
			
			let count: Int = 2
			
			states = RingBuffer<State>(array: (0..<count).map{(_)in
				return State(
					train: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
					value: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
					error: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
				)
			})
			levels = RingBuffer<Level>(array: (0..<count).map{(_)in
				return Level(
					value: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
					mu: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
					sigma: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
				)
			})
			deltas = RingBuffer<Delta>(array: (0..<count).map{(_)in
				return Delta(
					value: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
					mu: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
					sigma: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
				)
			})
		
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		
		}
		iRefresh()
		oRefresh()
	}
}
extension Cell {
	internal func iRefresh() {
		
		if let context: Context = managedObjectContext as? Context where 0 < width {
			
			states.progress()
			
			let state: MTLBuffer = states.new.value
			let train: MTLBuffer = states.new.train
			let error: MTLBuffer = states.new.error
			
			levels.progress()
			
			let value: MTLBuffer = levels.new.value
			let mu: MTLBuffer = levels.new.mu
			let sigma: MTLBuffer = levels.new.sigma

			context.newBlitCommand {

				$0.fillBuffer(state, range: NSRange(location: 0, length: state.length), value: 0)
				$0.fillBuffer(train, range: NSRange(location: 0, length: train.length), value: 0)
				$0.fillBuffer(error, range: NSRange(location: 0, length: error.length), value: 0)
				
				$0.fillBuffer(value, range: NSRange(location: 0, length: value.length), value: 0)
				$0.fillBuffer(mu, range: NSRange(location: 0, length: mu.length), value: 0)
				$0.fillBuffer(sigma, range: NSRange(location: 0, length: sigma.length), value: 0)
				
			}
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		
		}
		bias.refresh()
	}
	private func oRefresh() {
		
		if let context: Context = managedObjectContext as? Context where 0 < width {
			
			deltas.progress()
			
			let value: MTLBuffer = deltas.new.value
			let mu: MTLBuffer = deltas.new.mu
			let sigma: MTLBuffer = deltas.new.sigma
			
			context.newBlitCommand {
				$0.fillBuffer(value, range: NSRange(location: 0, length: value.length), value: 0)
				$0.fillBuffer(mu, range: NSRange(location: 0, length: mu.length), value: 0)
				$0.fillBuffer(sigma, range: NSRange(location: 0, length: sigma.length), value: 0)
			}
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		
		}
	}
	
	public func iClear(let ignore: Set<Cell>=[]) {
		if ignore.contains(self) {
			
		} else if ready.contains(.State) {
			input.forEach {
				$0.shuffle()
				$0.input.iClear(ignore.union([self]))
			}
			iRefresh()
			ready.remove(.State)
		}
	}
	public func oClear(let ignore: Set<Cell>=[]) {
		if ignore.contains(self) {
		
		} else if ready.contains(.Delta) {
			output.forEach {
				$0.refresh()
				$0.output.oClear(ignore.union([self]))
			}
			oRefresh()
			ready.remove(.Delta)
		}
	}
	
	public func collect(let visit visit: Set<Cell>=[]) -> MTLBuffer {
		
		if visit.contains(self) {
			return states.old.value
			
		} else {
			
			if ready.contains(.State) {
				return states.new.value
				
			} else if let context: Context = managedObjectContext as? Context {
				
				input.forEach {
					$0.collect(level: (levels.new.value, levels.new.mu, levels.new.sigma), visit: visit.union([self]))
				}
				bias.collect(level: (levels.new.value, levels.new.mu, levels.new.sigma))
				self.dynamicType.activate(context: context,
				                          state: states.new.value,
				                          level: levels.new.value,
				                          width: width)
				ready.insert(.State)
				
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
		}
		return states.new.value
	}
	public func correct(let η η: Float, let visit: Set<Cell>=[]) -> (MTLBuffer, MTLBuffer, MTLBuffer) {
		if visit.contains(self) {
			return(deltas.old.value, deltas.old.mu, deltas.old.sigma)
			
		} else {
			if ready.contains(.Delta) {
				return(deltas.new.value, deltas.new.mu, deltas.new.sigma)
				
			} else if ready.contains(.State) {
				if let context: Context = managedObjectContext as? Context {

					if ready.contains(.Train) {
						self.dynamicType.difference(context: context,
						                            error: states.new.error,
						                            train: states.new.train,
						                            state: states.new.value,
						                            width: width)
					
					} else {
						output.forEach {
							$0.correct(error: states.new.error, η: η, state: states.new.value, visit: visit.union([self]))
						}
						
					}
					self.dynamicType.derivate(context: context,
					                          delta: (deltas.new.value, deltas.new.mu, deltas.new.sigma),
					                          level: (levels.new.value, levels.new.mu, levels.new.sigma),
					                          error: states.new.error,
					                          width: width)
					ready.insert(.Delta)
					
					bias.correct(η: η, Δ: (deltas.new.mu, deltas.new.sigma))
					
				} else {
					assertionFailure(Context.Error.InvalidContext.rawValue)
					
				}
			}
		}
		return(deltas.new.value, deltas.new.mu, deltas.new.sigma)
	}
}
extension Cell {
	public var active: [Bool] {
		set {
			if let context: Context = managedObjectContext as? Context {
				let cache: MTLBuffer = context.newBuffer((0..<width).map{$0<newValue.count ? newValue[$0] ? 1:0:0}, options: .StorageModePrivate)
				let value: MTLBuffer = states.new.value
				let size: Int = sizeof(Float) * width
				
				assert(size==cache.length)
				assert(size==value.length)
				
				context.newBlitCommand(complete: { cache.setPurgeableState(.Empty) }) {
					$0.copyFromBuffer(cache, sourceOffset: 0, toBuffer: value, destinationOffset: 0, size: size)
				}
				ready.insert(.State)
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
		}
		get {
			collect()
			if let context: Context = managedObjectContext as? Context {
				let cache: MTLBuffer = context.newBuffer(length: sizeof(Float)*width, options: .CPUCacheModeDefaultCache)
				let value: MTLBuffer = states.new.value
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
				let train: MTLBuffer = states.new.train
				let size: Int = sizeof(Float) * width
				
				assert(size==cache.length)
				assert(size==train.length)
				
				context.newBlitCommand(complete: { cache.setPurgeableState(.Empty) }) {
					$0.copyFromBuffer(cache, sourceOffset: 0, toBuffer: train, destinationOffset: 0, size: size)
				}
				ready.insert(.Train)
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
		}
		get {
			if let context: Context = managedObjectContext as? Context {
				let cache: MTLBuffer = context.newBuffer(length: sizeof(Float)*width, options: .CPUCacheModeDefaultCache)
				let train: MTLBuffer = states.new.train
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
	internal static func difference(let context context: Context, let error: MTLBuffer, let train: MTLBuffer, let state: MTLBuffer, let width: Int) {
		context.newComputeCommand(function: differenceKernel) {
			$0.setBuffer(error, offset: 0, atIndex: 0)
			$0.setBuffer(train, offset: 0, atIndex: 1)
			$0.setBuffer(state, offset: 0, atIndex: 2)
			$0.dispatchThreadgroups(MTLSize(width: width/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func activate(let context context: Context, let state: MTLBuffer, let level: MTLBuffer, let width: Int) {
		context.newComputeCommand(function: activateKernel) {
			$0.setBuffer(state, offset: 0, atIndex: 0)
			$0.setBuffer(level, offset: 0, atIndex: 1)
			$0.dispatchThreadgroups(MTLSize(width: width/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func derivate(let context context: Context, let delta: (MTLBuffer, MTLBuffer, MTLBuffer), let level: (MTLBuffer, MTLBuffer, MTLBuffer), let error: MTLBuffer, let width: Int) {
		context.newComputeCommand(function: derivateKernel) {
			$0.setBuffer(delta.0, offset: 0, atIndex: 0)
			$0.setBuffer(delta.1, offset: 0, atIndex: 1)
			$0.setBuffer(delta.2, offset: 0, atIndex: 2)
			$0.setBuffer(level.0, offset: 0, atIndex: 3)
			$0.setBuffer(level.1, offset: 0, atIndex: 4)
			$0.setBuffer(level.2, offset: 0, atIndex: 5)
			$0.setBuffer(error, offset: 0, atIndex: 6)
			$0.setBytes([Float(M_PI)], length: sizeof(Float), atIndex: 7)
			$0.dispatchThreadgroups(MTLSize(width: width/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func forget(let context context: Context, let error: MTLBuffer, let rate: Float, let width: Int) {
		context.newComputeCommand(function: "cellForget") {
			$0.setBuffer(error, offset: 0, atIndex: 0)
			$0.setBytes([rate], length: sizeof(Float), atIndex: 1)
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
		try input.forEach {
			try newEdge(output: cell, input: $0)
		}
		cell.bias = try newBias(width: cell.width)
		cell.setup()
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
	public func unchainCell(let output output: Cell, let input: Cell) {
		output.input.filter{ $0.input === input }.forEach {
			deleteObject($0)
		}
	}
}