
//
//  Cell.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import Accelerate
import CoreData

public class Cell: NSManagedObject {
	private enum Ready {
		case State
		case Delta
		case Train
	}
	private var ready: Set<Ready> = Set<Ready>()
	internal var delta = (
		mean: la_splat_from_float(0, Config.ATTR),
		variance: la_splat_from_float(0, Config.ATTR),
		past: (
			mean: la_splat_from_float(0, Config.ATTR),
			variance: la_splat_from_float(0, Config.ATTR)
		)
	)
	internal var state = (
		train: la_splat_from_float(0, Config.ATTR),
		value: la_splat_from_float(0, Config.ATTR),
		past: (
			train: la_splat_from_float(0, Config.ATTR),
			value: la_splat_from_float(0, Config.ATTR)
		)
	)
	private var potential = (
		train: la_splat_from_float(0, Config.ATTR),
		value: la_splat_from_float(0, Config.ATTR),
		mean: la_splat_from_float(0, Config.ATTR),
		variance: la_splat_from_float(0, Config.ATTR)
	)
	private let mutex = (
		state: NSLock(),
		delta: NSLock()
	)
	private let group = (
		state: dispatch_group_create(),
		delta: dispatch_group_create()
	)
}
extension Cell {
	@NSManaged public private(set) var label: String
	@NSManaged public private(set) var width: UInt
	@NSManaged public var attribute: [String: AnyObject]
	@NSManaged private var input: Set<Edge>
	@NSManaged private var output: Set<Edge>
	@NSManaged private var bias: Bias
	@NSManaged private var feedback: Feedback?
	@NSManaged private var decay: Decay
}
extension Cell {
	public override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
}
extension Cell {
	internal func setup() {
		
		potential.train = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		potential.value = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		
		potential.mean = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		potential.variance = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		
		assert(potential.value.status==LA_SUCCESS && potential.value.width==width)
		assert(potential.mean.status==LA_SUCCESS && potential.mean.width==width)
		assert(potential.variance.status==LA_SUCCESS && potential.variance.width==width)
		
		state.value = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		state.train = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		
		assert(state.value.status==LA_SUCCESS && state.value.width==width)
		assert(state.train.status==LA_SUCCESS && state.train.width==width)
		
		state.past.train = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		state.past.value = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		
		assert(state.past.value.status==LA_SUCCESS && state.past.value.width==width)
		assert(state.past.train.status==LA_SUCCESS && state.past.train.width==width)
		
		delta.mean = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		delta.variance = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		
		assert(delta.mean.status==LA_SUCCESS && delta.mean.width==width)
		assert(delta.variance.status==LA_SUCCESS && delta.variance.width==width)
		
		delta.past.mean = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		delta.past.variance = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		
		assert(delta.past.mean.status==LA_SUCCESS && delta.past.mean.width==width)
		assert(delta.past.variance.status==LA_SUCCESS && delta.past.variance.width==width)
		
		refresh()
		forget()
		
	}
}
extension Cell {
	private func refresh() {
		
		state.past.train = state.train
		assert(state.past.train.status==LA_SUCCESS)
		
		state.past.value = state.value
		assert(state.past.value.status==LA_SUCCESS)
		
		//potential.value = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		//potential.mean = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		//potential.variance = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		
		potential.train = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		potential.value = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		potential.mean = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		potential.variance = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		
		assert(potential.train.status==LA_SUCCESS)
		assert(potential.value.status==LA_SUCCESS)
		assert(potential.mean.status==LA_SUCCESS)
		assert(potential.variance.status==LA_SUCCESS)
		
		bias.shuffle()
		feedback?.shuffle()
		decay.refresh()
		
	}
	private func forget() {
		
		delta.past.mean = delta.mean.dup
		delta.past.variance = delta.variance.dup
		
		assert(delta.past.mean.status==LA_SUCCESS && delta.past.mean.width == width)
		assert(delta.past.variance.status==LA_SUCCESS && delta.past.variance.width == width)
		
		delta.mean = la_splat_from_float(0, Config.ATTR)
		delta.variance = la_splat_from_float(0, Config.ATTR)
		
		assert(delta.mean.status==LA_SUCCESS)
		assert(delta.variance.status==LA_SUCCESS)
		
	}
	public func iClear(let visit: Set<Cell>=[]) {
		if visit.contains(self) {
			
		} else {
			if mutex.state.tryLock() {
				if ready.contains(.State) {
					guard let context: Context = managedObjectContext as? Context else {
						assertionFailure(Error.System.InvalidContext.description)
						return
					}
					dispatch_apply(input.count, context.dispatch.parallel) {
						let edge: Edge = self.input[self.input.startIndex.advancedBy($0)]
						edge.shuffle()
						edge.input.iClear(visit.union([self]))
					}
					refresh()
					ready.remove(.State)
				}
				mutex.state.unlock()
			}
		}
	}
	public func oClear(let visit: Set<Cell> = []) {
		if visit.contains(self) {
		
		} else {
			if mutex.delta.tryLock() {
				if ready.contains(.Delta) {
					guard let context: Context = managedObjectContext as? Context else {
						assertionFailure(Error.System.InvalidContext.description)
						return
					}
					dispatch_apply(output.count, context.dispatch.parallel) {
						let edge: Edge = self.output[self.output.startIndex.advancedBy($0)]
						edge.output.oClear(visit.union([self]))
					}
					forget()
					ready.remove(.Delta)
				}
				mutex.delta.unlock()
			}
		}
	}
	
	public func collect() {
		collect(visit: [])
	}
	internal func collect(let visit visit: Set<Cell>) -> (la_object_t) {
		if visit.contains(self) {
			return state.past.value
			
		} else {
			mutex.state.lock()
			if ready.contains(.State) {
				
			} else {
				guard let context: Context = managedObjectContext as? Context else {
					assertionFailure(Error.System.InvalidContext.description)
					return state.past.value
				}
				dispatch_apply(input.count, context.dispatch.parallel) {
					let edge: Edge = self.input[self.input.startIndex.advancedBy($0)]
					let(value,mean,variance) = edge.collect(visit.union([self]))
					dispatch_group_async(self.group.state, context.dispatch.serial) {
						self.potential.value = self.potential.value + value
						self.potential.mean = self.potential.mean + mean
						self.potential.variance = self.potential.variance + variance
					}
				}
				dispatch_group_wait(group.state, DISPATCH_TIME_FOREVER)
				
				if let(value, mean, variance) = feedback?.collect() {
					potential.value = potential.value + value
					potential.mean = potential.mean + mean
					potential.variance = potential.variance + variance
				}
				
				let(value, mean, variance) = bias.collect()
				potential.value = potential.value + value
				potential.mean = potential.mean + mean
				potential.variance = potential.variance + variance
				
				state.value = step(potential.value)
				
				ready.insert(.State)
			}
			mutex.state.unlock()
		}
		return state.value
	}
	public func correct(let eps eps: Float) {
		correct(eps: eps, visit: [])
	}
	internal func correct(let eps eps: Float, let visit: Set<Cell>) -> (la_object_t) {
		if visit.contains(self) {
			return delta.past.mean
			
		} else {
			mutex.delta.lock()
			if ready.contains(.Delta) {
				
			} else if ready.contains(.State) {
				
				guard let context: Context = managedObjectContext as? Context else {
					assertionFailure(Error.System.InvalidContext.description)
					return delta.past.mean
				}
				if ready.contains(.Train) {
					potential.train = potential.train + state.train - state.value
					
				} else {
					dispatch_apply(output.count, context.dispatch.parallel) {
						let edge: Edge = self.output[self.output.startIndex.advancedBy($0)]
						let delta: la_object_t = la_matrix_product(la_transpose(edge.value), edge.output.correct(eps: eps, visit: visit.union([self])))
						dispatch_group_async(self.group.delta, context.dispatch.serial) {
							self.potential.train = self.potential.train + delta
						}
					}
					dispatch_group_wait(group.delta, DISPATCH_TIME_FOREVER)
				}
				
				delta.mean = potential.train * pdf(x: la_splat_from_float(0, Config.ATTR), mu: potential.value, sigma: sqrt(potential.variance))
				delta.variance = delta.mean * potential.mean / potential.variance
				
				assert(delta.mean.status==LA_SUCCESS)
				assert(delta.variance.status==LA_SUCCESS)
				
				decay.gradient = la_matrix_product(la_diagonal_matrix_from_vector(decay.lambda, 0), decay.gradient) + la_diagonal_matrix_from_vector(decay.lambda, 0)
				if let feedback: Feedback = feedback {
					decay.gradient = decay.gradient +
					la_matrix_product(feedback.value, la_matrix_product(la_diagonal_matrix_from_vector(delta.past.mean, 0), feedback.gradient))
				}
				decay.correct(eps: eps, delta: delta.mean)
				decay.commit()
				
				dispatch_apply(input.count, context.dispatch.parallel) {
					let edge: Edge = self.input[self.input.startIndex.advancedBy($0)]
					if let feedback: Feedback = self.feedback {
						edge.gradient = (la_matrix_product(feedback.value, la_matrix_product(la_diagonal_matrix_from_vector(self.delta.past.mean, 0), edge.gradient)) + la_transpose(edge.input.state.value).toIdentity(self.width)).dup
					} else {
						edge.gradient = (la_transpose(edge.input.state.value).toIdentity(self.width))
					}
					edge.correct(eps: eps, mean: self.delta.mean, variance: self.delta.variance)
					edge.commit()
				}
				
				if let feedback: Feedback = feedback {
					feedback.gradient = (la_matrix_product(feedback.value, la_matrix_product(la_diagonal_matrix_from_vector(delta.past.mean, 0), feedback.gradient)) + la_transpose(state.past.value).toIdentity(width)).dup
					feedback.correct(eps: eps, mean: delta.mean, variance: delta.variance)
					feedback.commit()
				}

				if let feedback: Feedback = feedback {
					bias.gradient = (la_matrix_product(feedback.value, la_matrix_product(la_diagonal_matrix_from_vector(delta.past.mean, 0), bias.gradient)) + la_identity_matrix(width, la_scalar_type_t(LA_SCALAR_TYPE_FLOAT), Config.ATTR)).dup
				} else {
					bias.gradient = (la_identity_matrix(width, la_scalar_type_t(LA_SCALAR_TYPE_FLOAT), Config.ATTR))
				}
				bias.correct(eps: eps, mean: delta.mean, variance: delta.variance)
				bias.commit()
				
				ready.insert(.Delta)
			}
			mutex.delta.unlock()
		}
		return delta.mean
	}
}
extension Cell {
	public var active: [Bool] {
		set {
			assert(width==UInt(newValue.count))
			state.value = la_matrix_from_float_buffer(newValue.map{Float($0)}, width, 1, 1, Config.HINT, Config.ATTR)
			assert(state.value.status==LA_SUCCESS)
			ready.insert(.State)
		}
		get {
			collect()
			assert(state.value.width==width)
			return state.value.eval.map{Bool($0)}
		}
	}
	public var answer: [Bool] {
		set {
			assert(width==UInt(newValue.count))
			state.train = la_matrix_from_float_buffer(newValue.map{Float($0)}, width, 1, 1, Config.HINT, Config.ATTR)
			assert(state.train.status==LA_SUCCESS)
			ready.insert(.Train)
		}
		get {
			assert(state.train.width==width)
			return state.train.eval.map{Bool($0)}
		}
	}
}
extension Context {
	public func newCell ( let width width: UInt, let label: String = "", let recur: Bool = false, let input: [Cell] = [] ) throws -> Cell {
		guard let cell: Cell = new() else {
			throw Error.EntityError.InsertionFails(entity: NSStringFromClass(Cell.self))
		}
		cell.label = label
		cell.width = width
		cell.attribute = [:]
		cell.input = Set<Edge>()
		cell.output = Set<Edge>()
		try input.forEach {
			try newEdge(output: cell, input: $0)
		}
		if recur {
			cell.feedback = try newFeedback(width: width)
		}
		cell.bias = try newBias(width: width)
		cell.decay = try newDecay(width: width)
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
		output.input.filter { $0.input === input } .forEach {
			deleteObject($0)
		}
	}
}