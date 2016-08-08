
//
//  Cell.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

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
	}
	
	private struct Level {
		let error: MTLBuffer
		let value: MTLBuffer
		let mean: MTLBuffer
		let variance: MTLBuffer
	}
	
	private struct Delta {
		let mean: MTLBuffer
		let variance: MTLBuffer
	}
	
	private var state: [State] = []
	private var level: [Level] = []
	private var delta: [Delta] = []
	
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
	override public func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
}

extension Cell {
	internal func setup() {
		
		if let context: Context = managedObjectContext as? Context {
			
			state = [
				State(
					train: context.newBuffer(length: sizeof(Float)*width),
					value: context.newBuffer(length: sizeof(Float)*width)
				),
				State(
					train: context.newBuffer(length: sizeof(Float)*width),
					value: context.newBuffer(length: sizeof(Float)*width)
				)
			]
			
			level = [
				Level(
					error: context.newBuffer(length: sizeof(Float)*width),
					value: context.newBuffer(length: sizeof(Float)*width),
					mean: context.newBuffer(length: sizeof(Float)*width),
					variance: context.newBuffer(length: sizeof(Float)*width)
				),
				Level(
					error: context.newBuffer(length: sizeof(Float)*width),
					value: context.newBuffer(length: sizeof(Float)*width),
					mean: context.newBuffer(length: sizeof(Float)*width),
					variance: context.newBuffer(length: sizeof(Float)*width)
				)
			]
			
			delta = [
				Delta(
					mean: context.newBuffer(length: sizeof(Float)*width),
					variance: context.newBuffer(length: sizeof(Float)*width)
				),
				Delta(
					mean: context.newBuffer(length: sizeof(Float)*width),
					variance: context.newBuffer(length: sizeof(Float)*width)
				)
			]
		
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		
		}
		
		bias.setup()
		
		refresh()
		forget()
		
	}
}
extension Cell {
	internal func refresh() {
		
		if let context: Context = managedObjectContext as? Context where 0 < width {
			
			let newState: MTLBuffer = state[0].value
			let oldState: MTLBuffer = state[1].value
			
			assert(newState.length==oldState.length)
			
			let newTrain: MTLBuffer = state[0].train
			let oldTrain: MTLBuffer = state[1].train
			
			assert(newTrain.length==oldTrain.length)
			
			let newLevel: MTLBuffer = level[0].value
			let oldLevel: MTLBuffer = level[1].value
			
			assert(newLevel.length==oldLevel.length)
			
			let newError: MTLBuffer = level[0].error
			let oldError: MTLBuffer = level[1].error
			
			assert(newError.length==oldError.length)
			
			let newMean: MTLBuffer = level[0].mean
			let oldMean: MTLBuffer = level[1].mean
			
			assert(newMean.length==oldMean.length)
			
			let newVariance: MTLBuffer = level[0].variance
			let oldVariance: MTLBuffer = level[1].variance
			
			assert(newVariance.length==oldVariance.length)
			
			context.newBlitCommand {
				
				$0.copyFromBuffer(newState, sourceOffset: 0, toBuffer: oldState, destinationOffset: 0, size: min(newState.length, oldState.length))
				$0.copyFromBuffer(newTrain, sourceOffset: 0, toBuffer: oldTrain, destinationOffset: 0, size: min(newTrain.length, oldTrain.length))
				
				$0.fillBuffer(newState, range: NSRange(location: 0, length: newState.length), value: 0)
				$0.fillBuffer(newTrain, range: NSRange(location: 0, length: newTrain.length), value: 0)
				
				$0.copyFromBuffer(newLevel, sourceOffset: 0, toBuffer: oldLevel, destinationOffset: 0, size: min(newLevel.length, oldLevel.length))
				$0.copyFromBuffer(newError, sourceOffset: 0, toBuffer: oldError, destinationOffset: 0, size: min(newError.length, oldError.length))
				
				$0.fillBuffer(newLevel, range: NSRange(location: 0, length: newLevel.length), value: 0)
				$0.fillBuffer(newError, range: NSRange(location: 0, length: newError.length), value: 0)
				
				$0.copyFromBuffer(newMean, sourceOffset: 0, toBuffer: oldMean, destinationOffset: 0, size: min(newMean.length, oldMean.length))
				$0.copyFromBuffer(newVariance, sourceOffset: 0, toBuffer: oldVariance, destinationOffset: 0, size: min(newVariance.length, oldVariance.length))
				
				$0.fillBuffer(newMean, range: NSRange(location: 0, length: newMean.length), value: 0)
				$0.fillBuffer(newVariance, range: NSRange(location: 0, length: newVariance.length), value: 0)
				
			}
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		
		}
		bias.refresh()
	}
	private func forget() {
		
		if let context: Context = managedObjectContext as? Context where 0 < width {
			
			let newMean: MTLBuffer = delta[0].mean
			let oldMean: MTLBuffer = delta[1].mean
			
			assert(newMean.length==oldMean.length)
			
			let newVariance: MTLBuffer = delta[0].variance
			let oldVariance: MTLBuffer = delta[1].variance
			
			assert(newVariance.length==oldVariance.length)
			
			context.newBlitCommand {
				
				$0.copyFromBuffer(newMean, sourceOffset: 0, toBuffer: oldMean, destinationOffset: 0, size: min(newMean.length, oldMean.length))
				$0.copyFromBuffer(newVariance, sourceOffset: 0, toBuffer: oldVariance, destinationOffset: 0, size: min(newVariance.length, oldVariance.length))
				
				$0.fillBuffer(newMean, range: NSRange(location: 0, length: newMean.length), value: 0)
				$0.fillBuffer(newVariance, range: NSRange(location: 0, length: newVariance.length), value: 0)
				
			}
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		
		}
	}
	public func iClear(let visit: Set<Cell>=[]) {
		if visit.contains(self) {
			
		} else if ready.contains(.State) {
			input.forEach {
				$0.refresh()
				$0.input.iClear(visit.union([self]))
			}
			refresh()
			ready.remove(.State)
		}
	}
	public func oClear(let visit: Set<Cell> = []) {
		if visit.contains(self) {
		
		} else if ready.contains(.Delta) {
			output.forEach {
				$0.output.oClear(visit.union([self]))
			}
			forget()
			ready.remove(.Delta)
		}
	}
	
	public func collect() {
		collect(visit: [])
	
	}
	internal func collect(let visit visit: Set<Cell>) -> MTLBuffer {
		
		if visit.contains(self) {
			return state[1].value
			
		} else {
			
			if ready.contains(.State) {
				return state[0].value
				
			} else if let context: Context = managedObjectContext as? Context {
				
				let group: MTLSize = MTLSize(width: (width-1)/4+1, height: 1, depth: 1)
				let local: MTLSize = MTLSize(width: 1, height: 1, depth: 1)
				
				let state_value: MTLBuffer = state[0].value
				
				let level_value: MTLBuffer = level[0].value
				let level_mean: MTLBuffer = level[0].mean
				let level_variance: MTLBuffer = level[0].variance
				
				input.forEach {
					$0.collect(value: level_value, mean: level_mean, variance: level_variance, visit: visit.union([self]))
				}

				bias.collect(value: level_value, mean: level_mean, variance: level_variance)
				activate(context, state: state_value, level: level_value)
				ready.insert(.State)
				
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
		}
		return state[0].value
	}
	private func activate (let context: Context, let state: MTLBuffer, let level: MTLBuffer ) {
		
		let group: MTLSize = MTLSize(width: (width-1)/4+1, height: 1, depth: 1)
		let local: MTLSize = MTLSize(width: 1, height: 1, depth: 1)
		
		context.newComputeCommand(function: "step") {
			$0.setBuffer(state, offset: 0, atIndex: 0)
			$0.setBuffer(level, offset: 0, atIndex: 1)
			$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
		}
	}
	public func correct(let eps eps: Float) {
		correct(eps: eps, visit: [])
	}
	internal func correct(let eps eps: Float, let visit: Set<Cell>) -> (MTLBuffer, MTLBuffer) {
		if visit.contains(self) {
			return(delta[1].mean, delta[1].variance)
			
		} else {
			if ready.contains(.Delta) {
				return(delta[0].mean, delta[0].variance)
				
			} else if ready.contains(.State) {
				if let context: Context = managedObjectContext as? Context where ready.contains(.State) {
					if ready.contains(.Train) {
						
						let group: MTLSize = MTLSize(width: (width-1)/4+1, height: 1, depth: 1)
						let local: MTLSize = MTLSize(width: 1, height: 1, depth: 1)
						
						let train: MTLBuffer = state[0].train
						let value: MTLBuffer = state[0].value
						
						context.newComputeCommand(function: "sub") {
							$0.setBuffer(train, offset: 0, atIndex: 0)
							$0.setBuffer(value, offset: 0, atIndex: 1)
							$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
						}
					
					} else {
						
						let group: MTLSize = MTLSize(width: (width-1)/4+1, height: 1, depth: 1)
						let local: MTLSize = MTLSize(width: 1, height: 1, depth: 1)
						
						output.forEach {
							$0.correct(eps: eps, visit: visit.union([self]))
						}
						
					}
					
				} else {
					assertionFailure(Context.Error.InvalidContext.rawValue)
					
				}
				
			} else {
				return(delta[1].mean, delta[1].variance)
				
			}
		}
		return(delta[0].mean, delta[0].variance)
	}
	private func derivate(let context: Context, let delta: MTLBuffer, let error: MTLBuffer) {
		
		let group: MTLSize = MTLSize(width: (width-1)/4+1, height: 1, depth: 1)
		let local: MTLSize = MTLSize(width: 1, height: 1, depth: 1)
		
		context.newComputeCommand(function: "sign") {
			$0.setBuffer(delta, offset: 0, atIndex: 0)
			$0.setBuffer(error, offset: 0, atIndex: 1)
			$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
		}
	}
}
extension Cell {
	public var active: [Bool] {
		set {
			if let context: Context = managedObjectContext as? Context where newValue.count <= width {
				let cache: MTLBuffer = context.newBuffer(newValue.map{Float($0)}, options: .StorageModePrivate)
				let value: MTLBuffer = state[0].value
				context.newBlitCommand(complete: {cache.setPurgeableState(.Empty) }) {
					$0.copyFromBuffer(cache, sourceOffset: 0, toBuffer: value, destinationOffset: 0, size: min(cache.length, value.length))
				}
				ready.insert(.State)
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
		}
		get {
			if let context: Context = managedObjectContext as? Context {
				let cache: MTLBuffer = context.newBuffer(length: sizeof(Float)*width)
				let value: MTLBuffer = state[0].value
				context.newBlitCommand(sync: true) {
					$0.copyFromBuffer(value, sourceOffset: 0, toBuffer: cache, destinationOffset: 0, size: min(cache.length, value.length))
				}
				return UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(cache.contents()), count: width).map{Bool($0)}
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
			return [Bool](count: width, repeatedValue: false)
		}
	}
	public var answer: [Bool] {
		set {
			if let context: Context = managedObjectContext as? Context where newValue.count <= width {
				let cache: MTLBuffer = context.newBuffer(newValue.map{Float($0)}, options: .StorageModePrivate)
				let train: MTLBuffer = state[0].train
				context.newBlitCommand(complete: { cache.setPurgeableState(.Empty) }) {
					$0.copyFromBuffer(cache, sourceOffset: 0, toBuffer: train, destinationOffset: 0, size: min(cache.length, train.length))
				}
				ready.insert(.Train)
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
		}
		get {
			if let context: Context = managedObjectContext as? Context {
				let cache: MTLBuffer = context.newBuffer(length: sizeof(Float)*width)
				let train: MTLBuffer = state[0].train
				context.newBlitCommand(sync: true) {
					$0.copyFromBuffer(train, sourceOffset: 0, toBuffer: cache, destinationOffset: 0, size: min(cache.length, train.length))
				}
				return UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(cache.contents()), count: width).map{Bool($0)}
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
			return [Bool](count: width, repeatedValue: false)
		}
	}
}
extension Context {
	public func newCell ( let width width: Int, let label: String = "", let recur: Bool = false, let buffer: Bool = false, let input: [Cell] = [] ) throws -> Cell {
		guard let cell: Cell = new() else {
			throw Error.CoreData.InsertionFails(entity: Cell.className())
		}
		cell.label = label
		cell.width = width
		cell.attribute = [:]
		cell.input = Set<Edge>()
		cell.output = Set<Edge>()
		try input.forEach {
			try newEdge(output: cell, input: $0)
		}
		cell.bias = try newBias(width: width)
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
	public func unchainCell(let output output: Cell, let input: Cell) {
		output.input.filter{ $0.input === input }.forEach {
			deleteObject($0)
		}
	}
}