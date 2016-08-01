
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
	private var delta = (
		value: la_splat_from_float(0, Config.ATTR),
		mean: la_splat_from_float(0, Config.ATTR),
		variance: la_splat_from_float(0, Config.ATTR),
		past: (
			value: la_splat_from_float(0, Config.ATTR),
			mean: la_splat_from_float(0, Config.ATTR),
			variance: la_splat_from_float(0, Config.ATTR)
		)
	)
	private var state = (
		train: la_splat_from_float(0, Config.ATTR),
		value: la_splat_from_float(0, Config.ATTR),
		mean: la_splat_from_float(0, Config.ATTR),
		variance: la_splat_from_float(0, Config.ATTR),
		past: (
			value: la_splat_from_float(0, Config.ATTR),
			mean: la_splat_from_float(0, Config.ATTR),
			variance: la_splat_from_float(0, Config.ATTR)
		)
	)
	private var potential = (
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
	@NSManaged internal var lambdadata: NSData
	@NSManaged private var input: Set<Edge>
	@NSManaged private var output: Set<Edge>
	@NSManaged private var bias: Bias
	@NSManaged private var feedback: Feedback?
}
extension Cell {
	public override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
}
extension Cell {
	internal func setup() {
		
		potential.mean = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		potential.value = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		potential.variance = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		
		assert(potential.value.status==LA_SUCCESS && potential.value.width==width)
		assert(potential.mean.status==LA_SUCCESS && potential.mean.width==width)
		assert(potential.variance.status==LA_SUCCESS && potential.variance.width==width)
		
		state.value = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		state.mean = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		state.variance = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		
		assert(state.value.status==LA_SUCCESS && state.value.width==width)
		assert(state.mean.status==LA_SUCCESS && state.mean.width==width)
		assert(state.variance.status==LA_SUCCESS && state.variance.width==width)
		
		state.past.value = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		state.past.mean = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		state.past.variance = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		
		assert(state.past.value.status==LA_SUCCESS && state.past.value.width==width)
		assert(state.past.mean.status==LA_SUCCESS && state.past.mean.width==width)
		assert(state.past.variance.status==LA_SUCCESS && state.past.variance.width==width)
		
		delta.value = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		delta.mean = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		delta.variance = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		
		assert(delta.value.status==LA_SUCCESS && delta.value.width==width)
		assert(delta.mean.status==LA_SUCCESS && delta.mean.width==width)
		assert(delta.variance.status==LA_SUCCESS && delta.variance.width==width)
		
		delta.past.value = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		delta.past.mean = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		delta.past.variance = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		
		assert(delta.past.value.status==LA_SUCCESS && delta.past.value.width==width)
		assert(delta.past.mean.status==LA_SUCCESS && delta.past.mean.width==width)
		assert(delta.past.variance.status==LA_SUCCESS && delta.past.variance.width==width)
		
		refresh()
		forget()
		
	}
}
extension Cell {
	private func refresh() {
		
		state.past.value = state.value.dup
		state.past.mean = state.mean.dup
		state.past.variance = state.variance.dup
		
		assert(state.past.mean.status==LA_SUCCESS)
		assert(state.past.variance.status==LA_SUCCESS)
		assert(state.past.value.status==LA_SUCCESS)
		
		potential.value = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		potential.mean = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		potential.variance = la_vector_from_splat(la_splat_from_float(0, Config.ATTR), width)
		
		assert(potential.mean.status==LA_SUCCESS)
		assert(potential.variance.status==LA_SUCCESS)
		assert(potential.value.status==LA_SUCCESS)
		
		bias.shuffle()
		feedback?.shuffle()
		
	}
	private func forget() {
		
		delta.past.value = delta.value.dup
		delta.past.mean = delta.mean.dup
		delta.past.variance = delta.variance.dup
		
		assert(delta.past.value.status==LA_SUCCESS && delta.past.value.width == width)
		assert(delta.past.mean.status==LA_SUCCESS && delta.past.mean.width == width)
		assert(delta.past.variance.status==LA_SUCCESS && delta.past.variance.width == width)
		
		delta.value = la_splat_from_float(0, Config.ATTR)
		delta.mean = la_splat_from_float(0, Config.ATTR)
		delta.variance = la_splat_from_float(0, Config.ATTR)
		
		assert(delta.value.status==LA_SUCCESS)
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
					let refer: Set<Edge> = input
					dispatch_apply(refer.count, context.dispatch.parallel) {
						let edge: Edge = refer[refer.startIndex.advancedBy($0)]
//					refer.forEach {(let edge: Edge)in
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
					let refer: Set<Edge> = output
					dispatch_apply(refer.count, context.dispatch.parallel) {
						let edge: Edge = refer[refer.startIndex.advancedBy($0)]
//					refer.forEach {(let edge: Edge)in
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
				let refer: Set<Edge> = input
				dispatch_apply(refer.count, context.dispatch.parallel) {
					let edge: Edge = refer[refer.startIndex.advancedBy($0)]
//				refer.forEach {(let edge: Edge)in
					let(value,mean,variance) = edge.collect(visit.union([self]))
					dispatch_group_async(self.group.state, context.dispatch.serial) {
						self.potential.value = self.potential.value + value
						self.potential.mean = self.potential.mean + mean
						self.potential.variance = self.potential.variance + variance
					}
				}
				dispatch_group_wait(group.state, DISPATCH_TIME_FOREVER)
				
				potential.value = potential.value + bias.value
				potential.mean = potential.mean + bias.mean
				potential.variance = potential.variance + bias.variance
				
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
	internal func correct(let eps eps: Float, let visit: Set<Cell>) -> (la_object_t, la_object_t) {
		if visit.contains(self) {
			return(delta.past.mean, delta.past.variance)
			
		} else {
			mutex.delta.lock()
			if ready.contains(.Delta) {
				
			} else if ready.contains(.State) {
				if ready.contains(.Train) {
					delta.value = delta.value + state.train - state.value
					
				} else {
					guard let context: Context = managedObjectContext as? Context else {
						assertionFailure(Error.System.InvalidContext.description)
						return(delta.past.mean, delta.past.variance)
					}
					let refer: Set<Edge> = output
					dispatch_apply(refer.count, context.dispatch.parallel) {
						let edge: Edge = refer[refer.startIndex.advancedBy($0)]
//					refer.forEach { (let edge: Edge)in
						let delta = edge.correct(eps: eps, visit: visit.union([self]))
						dispatch_group_async(self.group.delta, context.dispatch.serial) {
							self.delta.value = self.delta.value + delta
						}
					}
					dispatch_group_wait(group.delta, DISPATCH_TIME_FOREVER)
				}
				
				delta.mean = pdf(x: la_splat_from_float(0, Config.ATTR), mu: potential.value, sigma: sqrt(potential.variance)) * sign(delta.value)
				delta.variance = delta.mean * potential.mean / potential.variance
				
				assert(delta.mean.status==LA_SUCCESS)
				assert(delta.variance.status==LA_SUCCESS)
				
				bias.mean = bias.mean + ( eps ) * delta.mean
				bias.logvariance = bias.logvariance - ( 0.5 * eps ) * bias.variance * delta.variance
				bias.commit()

				ready.insert(.Delta)
			}
			mutex.delta.unlock()
		}
		return(delta.mean, delta.variance)
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
		cell.lambdadata = NSData(bytes: [Float](count: Int(width), repeatedValue: 0), length: sizeof(Float)*Int(width))
		cell.input = Set<Edge>()
		cell.output = Set<Edge>()
		try input.forEach {
			try newEdge(output: cell, input: $0)
		}
		if recur {
			cell.feedback = try newFeedback(width: width)
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
		output.input.filter { $0.input === input } .forEach {
			deleteObject($0)
		}
	}
}
