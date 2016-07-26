
//
//  Cell.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import Accelerate
import NLA

public class Cell: NSManagedObject {
	private static let ATTR: la_attribute_t = la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)
	private static let HINT: la_hint_t = la_hint_t(LA_NO_HINT)
	private enum Ready {
		case State
		case Delta
		case Learn
	}
	private let dlock: dispatch_semaphore_t = dispatch_semaphore_create(1)
	private let slock: dispatch_semaphore_t = dispatch_semaphore_create(1)
	private var ready: Set<Ready> = Set<Ready>()
	private var delta = (
		mean: la_splat_from_float(0, ATTR),
		variance: la_splat_from_float(0, ATTR)
	)
	private var desired = (
		value: la_splat_from_float(0, ATTR),
		mean: la_splat_from_float(0, ATTR),
		variance: la_splat_from_float(1, ATTR)
	)
	private var state = (
		value: la_splat_from_float(0, ATTR),
		probably: la_splat_from_float(0, ATTR)
	)
	private var potential = (
		value: la_splat_from_float(0, ATTR),
		mean: la_splat_from_float(0, ATTR),
		variance: la_splat_from_float(1, ATTR)
	)
	private var const = (
		value: la_splat_from_float(0, ATTR),
		mean: la_splat_from_float(0, ATTR),
		deviation: la_splat_from_float(1, ATTR),
		variance: la_splat_from_float(1, ATTR),
		logvariance: la_splat_from_float(0, ATTR)//,
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
	func setup() {
		managedObjectContext?.performBlockAndWait {
			if let data: NSData = self.primitiveValueForKey("mean")as?NSData {
				self.setPrimitiveValue(NSData(data: data), forKey: "mean")
			}
			if let data: NSData = self.primitiveValueForKey("logvariance")as?NSData {
				self.setPrimitiveValue(NSData(data: data), forKey: "logvariance")
			}
		}
		const.mean = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(mean.bytes), width, 1, 1, Cell.HINT, nil, Cell.ATTR)
		const.logvariance = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(logvariance.bytes), width, 1, 1, Cell.HINT, nil, Cell.ATTR)
		refresh()
	}
	func commit() {
		managedObjectContext?.performBlockAndWait {
			self.willChangeValueForKey("mean")
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(self.mean.bytes), 1, self.const.mean)
			self.didChangeValueForKey("mean")
			
			self.willChangeValueForKey("logvariance")
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(self.logvariance.bytes), 1, self.const.logvariance)
			self.didChangeValueForKey("logvariance")
		}
		const.mean = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(mean.bytes), width, 1, 1, Cell.HINT, nil, Cell.ATTR)
		const.logvariance = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(logvariance.bytes), width, 1, 1, Cell.HINT, nil, Cell.ATTR)
		
	}
}
extension Cell {
	private func refresh() {
		
		const.deviation = exp(0.5*const.logvariance)
		const.variance = const.deviation * const.deviation
		const.value = const.mean + const.deviation * normal(rows: width, cols: 1)
		
		potential.mean = const.mean
		potential.variance = const.variance
		potential.value = const.value
		
	}
	private func forget() {
		
		delta.mean = la_splat_from_float(0, Cell.ATTR)
		delta.variance = la_splat_from_float(0, Cell.ATTR)
		
	}
	public func iClear() {
		slock.lock()
		if ready.contains(.State) {
			ready.remove(.State)
			refresh()
			dispatch_apply(input.count, Cell.dispatch.parallel) {
				self.input[self.input.startIndex.advancedBy($0)].iClear()
			}
		}
		slock.unlock()
	}
	public func oClear() {
		dlock.lock()
		if ready.contains(.Delta) {
			ready.remove(.Delta)
			ready.remove(.Learn)
			forget()
			dispatch_apply(output.count, Cell.dispatch.parallel) {
				self.output[self.output.startIndex.advancedBy($0)].oClear()
			}
		}
		dlock.unlock()
	}
	public func collect() -> la_object_t {
		slock.lock()
		if ready.contains(.State) {
			
		} else {
			ready.insert(.State)
			let lock: dispatch_semaphore_t = dispatch_semaphore_create(1)
			dispatch_apply(input.count, Cell.dispatch.parallel) {
				let edge: Edge = self.input[self.input.startIndex.advancedBy($0)]
				let (value, mean, variance) = edge.collect()

				lock.lock()
				self.potential.value = self.potential.value + value
				self.potential.mean = self.potential.mean + mean
				self.potential.variance = self.potential.variance + variance
				lock.unlock()
			}
			state.value = step(potential.value)
		}
		slock.unlock()
		return state.value
	}
	public func correct(let eps eps: Float) -> (la_object_t, la_object_t) {
		dlock.lock()
		if ready.contains(.Delta) {
		
		} else if ready.contains(.State) {
			ready.insert(.Delta)
			var error: la_object_t = la_splat_from_float(0, Cell.ATTR)
			if ready.contains(.Learn) {
				error = desired.value - state.value
				
			} else {
				let lock: dispatch_semaphore_t = dispatch_semaphore_create(1)
				dispatch_apply(output.count, Cell.dispatch.parallel) {
					let edge: Edge = self.output[self.output.startIndex.advancedBy($0)]
					let delta: la_object_t = edge.correct(eps: eps)
					
					lock.lock()
					error = error + delta
					lock.unlock()
				}
			}
			delta.mean = pdf(x: la_splat_from_float(0, Cell.ATTR), mu: potential.value, sigma: sqrt(potential.variance)) * sign(error)
			delta.variance = delta.mean * potential.mean / potential.variance
			
			const.mean = const.mean + eps * delta.mean
			const.logvariance = const.logvariance - eps * 0.5 * const.variance * delta.variance
			
			commit()
		}
		dlock.unlock()
		return (delta.mean, delta.variance)
	}
}
extension Cell {
	var active: [Bool] {
		set {
			assert(width==UInt(newValue.count))
			state.value = la_matrix_from_float_buffer(newValue.map{Float($0)}, width, 1, 1, Cell.HINT, Cell.ATTR)
			assert(state.value.status==LA_SUCCESS)
			ready.insert(.State)
		}
		get {
			collect()
			assert(state.value.width==width)
			return state.value.eval.map{Bool($0)}
		}
	}
	var answer: [Bool] {
		set {
			assert(width==UInt(newValue.count))
			desired.value = la_matrix_from_float_buffer(newValue.map{Float($0)}, width, 1, 1, Cell.HINT, Cell.ATTR)
			assert(desired.value.status==LA_SUCCESS)
			ready.insert(.Learn)
		}
		get {
			assert(desired.value.width==width)
			return desired.value.eval.map{Bool($0)}
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
			cell.mean = NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count)
			cell.logvariance = NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count)
			cell.lambda = NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count)
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
extension Cell {
	private static let dispatch = (
		parallel: dispatch_queue_create("\(Config.identifier).\(NSStringFromClass(Cell.self)).queue", DISPATCH_QUEUE_CONCURRENT),
		group: dispatch_group_create()
	)
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