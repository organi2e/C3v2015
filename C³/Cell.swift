
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
	private var ready: Set<Ready> = Set<Ready>()
	private var delta = (
		mean: la_splat_from_float(0, ATTR),
		variance: la_splat_from_float(0, ATTR),
		lock: dispatch_semaphore_create(1)
	)
	private var desired = (
		value: la_splat_from_float(0, ATTR),
		mean: la_splat_from_float(0, ATTR),
		variance: la_splat_from_float(1, ATTR)
	)
	private var state = (
		value: la_splat_from_float(0, ATTR),
		probably: la_splat_from_float(0, ATTR),
		lock: dispatch_semaphore_create(1)
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
	func load() {

		setPrimitiveValue(NSData(data: mean), forKey: "mean")
		setPrimitiveValue(NSData(data: logvariance), forKey: "logvariance")

		const.mean = la_matrix_from_float_buffer(UnsafePointer<Float>(mean.bytes), width, 1, 1, Cell.HINT, Cell.ATTR)
		const.logvariance = la_matrix_from_float_buffer(UnsafePointer<Float>(logvariance.bytes), width, 1, 1, Cell.HINT, Cell.ATTR)
		
		refresh()
	}
	func save() {
		let buffer: [Float] = [Float](count: Int(width), repeatedValue: 0)

		assert(buffer.count==const.mean.count)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), 1, const.mean)
		mean = NSData(bytes: UnsafePointer<Void>(buffer), length: sizeof(Float)*buffer.count)
		
		assert(buffer.count==const.logvariance.count)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), 1, const.logvariance)
		logvariance = NSData(bytes: UnsafePointer<Void>(buffer), length: sizeof(Float)*buffer.count)
	}
	func sync() {
		
		let buffer: [Float] = [Float](count: Int(width), repeatedValue: 0)
		
		assert(buffer.count==const.mean.count)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), 1, const.mean)
		let mean = NSData(bytes: UnsafePointer<Void>(buffer), length: sizeof(Float)*buffer.count)
		
		assert(buffer.count==const.logvariance.count)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), 1, const.logvariance)
		let logvariance = NSData(bytes: UnsafePointer<Void>(buffer), length: sizeof(Float)*buffer.count)
		
		const.mean = la_matrix_from_float_buffer(UnsafePointer<Float>(mean.bytes), width, 1, 1, Cell.HINT, Cell.ATTR)
		const.logvariance = la_matrix_from_float_buffer(UnsafePointer<Float>(logvariance.bytes), width, 1, 1, Cell.HINT, Cell.ATTR)
		managedObjectContext?.performBlockAndWait {
			self.mean = mean
			self.logvariance = logvariance
		}
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
		
	}
	public func iClear() {
		state.lock.lock()
		if ready.contains(.State) {
			ready.remove(.State)
			refresh()
			dispatch_apply(input.count, Cell.dispatch.parallel) {
				self.input[self.input.startIndex.advancedBy($0)].iClear()
			}
		}
		state.lock.unlock()
	}
	public func oClear() {
		delta.lock.lock()
		if ready.contains(.Delta) {
			ready.remove(.Delta)
			ready.remove(.Learn)
			forget()
			dispatch_apply(output.count, Cell.dispatch.parallel) {
				self.output[self.output.startIndex.advancedBy($0)].oClear()
			}
		}
		delta.lock.unlock()
	}
	public func collect() -> la_object_t {
		state.lock.lock()
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
		state.lock.unlock()
		return state.value
	}
	public func correct(let eps eps: Float) -> (la_object_t, la_object_t) {
		delta.lock.lock()
		if ready.contains(.Delta) {
		
		} else {
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
			
			sync()
		}
		delta.lock.unlock()
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
extension Cell {
	public override func awakeFromFetch() {
		super.awakeFromFetch()
		load()
	}
}
extension Context {
	public func newCell ( let width width: UInt, let label: String = "", let recur: Bool = false, let input: [Cell] = [] ) -> Cell? {
		let cell: Cell? = new()
		//let width: UInt = ((size-1)/4+1)*4
		//size//max( size + 0x0f - ( ( size + 0x0f ) % 0x10 ), 0x10 )
		if let cell: Cell = cell {
			let count: Int = Int(width)
			cell.width = width
			cell.label = label
			cell.attribute = [:]
			cell.mean = NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count)
			cell.logvariance = NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count)
			cell.lambda = NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count)
			cell.load()
			input.forEach { ( let input: Cell ) in
				if let edge: Edge = new() {
					let count: Int = Int(cell.width * input.width)
					edge.setValue(input, forKey: "input")
					edge.setValue(cell, forKey: "output")
					edge.setValue(NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count), forKey: "mean")
					edge.setValue(NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count), forKey: "logvariance")
					edge.load()
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
		serial: dispatch_queue_create("\(Config.identifier).\(NSStringFromClass(Cell.self)).queue.serial", DISPATCH_QUEUE_SERIAL),
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