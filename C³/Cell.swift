
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
	private class Probably {
		var value: la_object_t = la_splat_from_float(0, Config.ATTR)
		var mean: la_object_t = la_splat_from_float(0, Config.ATTR)
		var deviation: la_object_t = la_splat_from_float(0, Config.ATTR)
		var variance: la_object_t = la_splat_from_float(0, Config.ATTR)
		var logvariance: la_object_t = la_splat_from_float(0, Config.ATTR)
	}
	private var ready: Set<Ready> = Set<Ready>()
	private var delta: Probably = Probably()
	private var state: Probably = Probably()
	private var train: Probably = Probably()
	private var potential: Probably = Probably()
	private var const: Probably = Probably()
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
	@NSManaged private var mean: NSData
	@NSManaged private var logvariance: NSData
	@NSManaged private var lambda: NSData
	@NSManaged private var input: Set<Edge>
	@NSManaged private var output: Set<Edge>
}
extension Cell {
	public override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
}
extension Cell {
	internal func setup() {
		
		setPrimitiveValue(NSData(data: mean), forKey: "mean")
		setPrimitiveValue(NSData(data: logvariance), forKey: "logvariance")

		const.mean = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(mean.bytes), width, 1, 1, Config.HINT, nil, Config.ATTR)
		const.logvariance = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(logvariance.bytes), width, 1, 1, Config.HINT, nil, Config.ATTR)
		
		assert(const.mean.status==LA_SUCCESS)
		assert(const.logvariance.status==LA_SUCCESS)
		
		refresh()
		forget()
		
	}
	internal func commit() {
		
		managedObjectContext?.performBlockAndWait {
			self.willChangeValueForKey("mean")
			self.willChangeValueForKey("logvariance")
		}
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(mean.bytes), 1, const.mean)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(logvariance.bytes), 1, const.logvariance)
		
		managedObjectContext?.performBlockAndWait {
			self.didChangeValueForKey("mean")
			self.didChangeValueForKey("logvariance")
		}
		
		const.mean = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(mean.bytes), width, 1, 1, Config.HINT, nil, Config.ATTR)
		const.logvariance = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(logvariance.bytes), width, 1, 1, Config.HINT, nil, Config.ATTR)
		
		assert(const.mean.status==LA_SUCCESS)
		assert(const.logvariance.status==LA_SUCCESS)
		
	}
}
extension Cell {
	private func refresh() {
		
		const.deviation = exp(0.5*const.logvariance)
		const.variance = const.deviation * const.deviation
		const.value = const.mean + const.deviation * normal(rows: width, cols: 1)
		
		assert(const.deviation.status==LA_SUCCESS)
		assert(const.variance.status==LA_SUCCESS)
		assert(const.value.status==LA_SUCCESS)
		
		potential.mean = const.mean
		potential.variance = const.variance
		potential.value = const.value
		
		assert(potential.mean.status==LA_SUCCESS)
		assert(potential.variance.status==LA_SUCCESS)
		assert(potential.value.status==LA_SUCCESS)
		
	}
	private func forget() {
		
		delta.value = la_splat_from_float(0, Config.ATTR)
		delta.mean = la_splat_from_float(0, Config.ATTR)
		delta.variance = la_splat_from_float(0, Config.ATTR)
		
		assert(delta.value.status==LA_SUCCESS)
		assert(delta.mean.status==LA_SUCCESS)
		assert(delta.variance.status==LA_SUCCESS)
		
	}
	public func iClear(let visit: Set<Cell> = []) {
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
						edge.iClear(visit.union([self]))
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
						edge.oClear(visit.union([self]))
					}
					forget()
					ready.remove(.Train)
					ready.remove(.Delta)
				}
				mutex.delta.unlock()
			}
		}
	}
	public func collect(let visit: Set<Cell> = []) -> la_object_t {
		if visit.contains(self) {
			return state.value
			
		} else {
			mutex.state.lock()
			if ready.contains(.State) {
				
			} else {
				guard let context: Context = managedObjectContext as? Context else {
					assertionFailure(Error.System.InvalidContext.description)
					return state.value
				}
				let refer: Set<Edge> = input
				dispatch_apply(refer.count, context.dispatch.parallel) {
					let edge: Edge = refer[refer.startIndex.advancedBy($0)]
					let(value,mean,variance) = edge.collect(visit.union([self]))
					dispatch_group_async(self.group.state, context.dispatch.serial) {
						self.potential.value = self.potential.value + value
						self.potential.mean = self.potential.mean + mean
						self.potential.variance = self.potential.variance + variance
					}
				}
				dispatch_group_wait(group.state, DISPATCH_TIME_FOREVER)
				
				state.value = step(potential.value)
				ready.insert(.State)
			}
			mutex.state.unlock()
		}
		return state.value
	}
	public func correct(let eps eps: Float, let visit: Set<Cell> = []) -> (la_object_t, la_object_t) {
		if visit.contains(self) {
			return(delta.mean, delta.variance)
			
		} else {
			mutex.delta.lock()
			if ready.contains(.Delta) {
				
			} else if ready.contains(.State) {
				if ready.contains(.Train) {
					delta.value = delta.value + train.value - state.value
					
				} else {
					guard let context: Context = managedObjectContext as? Context else {
						assertionFailure(Error.System.InvalidContext.description)
						return(delta.mean, delta.variance)
					}
					let refer: Set<Edge> = output
					dispatch_apply(refer.count, context.dispatch.parallel) {
						let edge: Edge = refer[refer.startIndex.advancedBy($0)]
						let delta = edge.correct(eps: eps, visit: visit.union([self]))
						dispatch_group_async(self.group.delta, context.dispatch.serial) {
							self.delta.value = self.delta.value + delta
						}
					}
					dispatch_group_wait(group.delta, DISPATCH_TIME_FOREVER)
				}
				
				delta.mean = pdf(x: la_splat_from_float(0, Config.ATTR), mu: potential.value, sigma: sqrt(potential.variance)) *
					sign(delta.value)
				delta.variance = delta.mean * potential.mean / potential.variance
				
				assert(delta.mean.status==LA_SUCCESS)
				assert(delta.variance.status==LA_SUCCESS)
				
				const.mean = const.mean + eps * delta.mean
				const.logvariance = const.logvariance - ( 0.5 * eps ) * const.variance * delta.variance
				
				assert(const.mean.status==LA_SUCCESS)
				assert(const.variance.status==LA_SUCCESS)
				
				commit()

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
			train.value = la_matrix_from_float_buffer(newValue.map{Float($0)}, width, 1, 1, Config.HINT, Config.ATTR)
			assert(train.value.status==LA_SUCCESS)
			ready.insert(.Train)
		}
		get {
			assert(train.value.width==width)
			return train.value.eval.map{Bool($0)}
		}
	}
}
extension Context {
	public func newCell ( let width width: UInt, let label: String = "", let recur: Bool = false, let input: [Cell] = [] ) -> Cell? {
		let cell: Cell? = new()
		if let cell: Cell = cell {
			let count: Int = Int(width)
			cell.width = width
			cell.label = label
			cell.attribute = [:]
			cell.setValue(NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count), forKey: "mean")
			cell.setValue(NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count), forKey: "logvariance")
			cell.setValue(NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count), forKey: "lambda")
			cell.setup()
			input.forEach { ( let input: Cell ) in
				if let edge: Edge = new() {
					let count: Int = Int(cell.width * input.width)
					edge.setValue(input, forKey: "input")
					edge.setValue(cell, forKey: "output")
					edge.setValue(NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count), forKey: "mean")
					edge.setValue(NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count), forKey: "logvariance")
					edge.setup()
				}
			}
		}
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
		let cell: [Cell] = fetch ( attribute )
		return cell
	}
}
extension Context {
	public func train( let pair: [([String:[Bool]], [String:[Bool]])], let count: Int, let eps: Float) {
		(0..<count).forEach {(_)in
			pair.forEach {
				$0.0.forEach {
					if let cell: Cell = searchCell(label: $0.0).first {
						cell.oClear()
						cell.active = $0.1
					}
				}
				$0.1.forEach {
					if let cell: Cell = searchCell(label: $0.0).first {
						cell.iClear()
						cell.answer = $0.1
					}
				}
				$0.0.forEach {
					if let cell: Cell = searchCell(label: $0.0).first {
						cell.correct(eps: eps)
					}
				}
				$0.1.forEach {
					if let cell: Cell = searchCell(label: $0.0).first {
						print(cell.active)
					}
				}
			}
		}
	}
}