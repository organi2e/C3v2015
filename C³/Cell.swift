
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
	private enum Ready {
		case State
		case Delta
		case Learn
	}
	private class Probably {
		var value: la_object_t = la_splat_from_float(0, Config.ATTR)
		var mean: la_object_t = la_splat_from_float(0, Config.ATTR)
		var deviation: la_object_t = la_splat_from_float(0, Config.ATTR)
		var variance: la_object_t = la_splat_from_float(0, Config.ATTR)
		var logvariance: la_object_t = la_splat_from_float(0, Config.ATTR)
		let lock: NSLock = NSLock()
	}
	private var ready: Set<Ready> = Set<Ready>()
	private var delta: Probably = Probably()
	private var desired: Probably = Probably()
	private var state: Probably = Probably()
	private var potential: Probably = Probably()
	private var const: Probably = Probably()
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

		const.mean = la_matrix_from_float_buffer(UnsafeMutablePointer<Float>(mean.bytes), width, 1, 1, Config.HINT, Config.ATTR)
		const.logvariance = la_matrix_from_float_buffer(UnsafeMutablePointer<Float>(logvariance.bytes), width, 1, 1, Config.HINT, Config.ATTR)
		
		refresh()
	}
	func commit() {
		
		if let mean: NSMutableData = NSMutableData(length: sizeof(Float)*Int(width)), logvariance: NSMutableData = NSMutableData(length: sizeof(Float)*Int(width)) {
			
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(mean.mutableBytes), 1, const.mean)
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(logvariance.mutableBytes), 1, const.logvariance)
			
			const.mean = la_matrix_from_float_buffer(UnsafePointer<Float>(mean.mutableBytes), width, 1, 1, Config.HINT, Config.ATTR)
			const.logvariance = la_matrix_from_float_buffer(UnsafePointer<Float>(logvariance.mutableBytes), width, 1, 1, Config.HINT, Config.ATTR)
			
			managedObjectContext?.performBlockAndWait {
				self.mean = mean
				self.logvariance = logvariance
			}
			
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
		
		delta.value = la_splat_from_float(0, Config.ATTR)
		delta.mean = la_splat_from_float(0, Config.ATTR)
		delta.variance = la_splat_from_float(0, Config.ATTR)
		
		desired.value = la_splat_from_float(0, Config.ATTR)
		desired.mean = la_splat_from_float(0, Config.ATTR)
		desired.variance = la_splat_from_float(0, Config.ATTR)
		
	}
	public func iClear() {
		if state.lock.tryLock() {
			if ready.contains(.State) {
				ready.remove(.State)
				refresh()
				dispatch_apply(input.count, Cell.dispatch.queue) {
					let edge: Edge = self.input[self.input.startIndex.advancedBy($0)]
					edge.iClear()
				}
			}
			state.lock.unlock()
		}
	}
	public func oClear() {
		if delta.lock.tryLock() {
			if ready.contains(.Delta) {
				ready.remove(.Delta)
				ready.remove(.Learn)
				forget()
				dispatch_apply(output.count, Cell.dispatch.queue) {
					let edge: Edge = self.output[self.output.startIndex.advancedBy($0)]
					edge.oClear()
				}
			}
			delta.lock.unlock()
		}
	}
	public func collect() -> la_object_t {
		state.lock.lock()
		if ready.contains(.State) {
			
		} else {
			ready.insert(.State)
			dispatch_apply(input.count, Cell.dispatch.queue) {
				
				let edge: Edge = self.input[self.input.startIndex.advancedBy($0)]
				let (value, mean, variance) = edge.collect()
				
				self.potential.lock.lock()
				self.potential.value = self.potential.value + value
				self.potential.mean = self.potential.mean + mean
				self.potential.variance = self.potential.variance + variance
				self.potential.lock.unlock()
				
			}
			state.value = step(potential.value)
		}
		state.lock.unlock()
		return state.value
	}
	public func correct(let eps eps: Float) -> (la_object_t, la_object_t) {
		delta.lock.lock()
		if ready.contains(.Delta) {
		
		} else if ready.contains(.State) {
			ready.insert(.Delta)
			if ready.contains(.Learn) {
				desired.mean = desired.value - state.value
				
			} else {
				dispatch_apply(output.count, Cell.dispatch.queue) {
					
					let edge: Edge = self.output[self.output.startIndex.advancedBy($0)]
					let delta: la_object_t = edge.correct(eps: eps)
					
					self.desired.lock.lock()
					self.desired.mean = self.desired.mean + delta
					self.desired.lock.unlock()
					
				}
			}
			delta.mean = pdf(x: la_splat_from_float(0, Config.ATTR), mu: potential.value, sigma: sqrt(potential.variance)) * sign(desired.mean)
			delta.variance = delta.mean * potential.mean / potential.variance
			
			const.mean = const.mean + eps * delta.mean
			const.logvariance = const.logvariance - eps * 0.5 * const.variance * delta.variance
			
			commit()
		}
		delta.lock.unlock()
		return (delta.mean, delta.variance)
	}
}
extension Cell {
	var active: [Bool] {
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
	var answer: [Bool] {
		set {
			assert(width==UInt(newValue.count))
			desired.value = la_matrix_from_float_buffer(newValue.map{Float($0)}, width, 1, 1, Config.HINT, Config.ATTR)
			assert(desired.value.status==LA_SUCCESS)
			ready.insert(.Learn)
		}
		get {
			assert(desired.value.width==width)
			return desired.value.eval.map{Bool($0)}
		}
	}
	static func commit(let task: ()->()) {
		dispatch_barrier_sync(Cell.dispatch.queue, task)
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
extension Cell {
	private static let dispatch = (
		queue: dispatch_queue_create("\(Config.identifier).\(NSStringFromClass(Cell.self)).queue", DISPATCH_QUEUE_CONCURRENT),
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