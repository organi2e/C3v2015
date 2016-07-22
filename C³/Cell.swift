//
//  Cell.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import Accelerate
import NLA

public class Cell: C3Object {
	private enum Ready {
		case State
		case Delta
		case Learn
		case Visit
	}
	private var ready: Set<Ready> = Set<Ready>()
	private var delta = (
		value: la_splat_from_float(0, ATTR),
		event: dispatch_group_create()
	)
	private var error = (
		value: la_splat_from_float(0, ATTR),
		mean: la_splat_from_float(0, ATTR),
		variance: la_splat_from_float(1, ATTR)
	)
	private var desired = (
		value: la_splat_from_float(0, ATTR),
		mean: la_splat_from_float(0, ATTR),
		variance: la_splat_from_float(1, ATTR)
	)
	private var state = (
		value: la_splat_from_float(0, ATTR),
		probably: la_splat_from_float(0, ATTR),
		event: dispatch_group_create()
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
		logvariance: la_splat_from_float(0, ATTR),
		event: dispatch_group_create()
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
	public func iClear() {
		enter()
		if ready.contains(.State) {
			deltaReady()
			refresh()
			ready.remove(.State)
		}
		leave()
	}
	public func oClear() {
		enter()
		if ready.contains(.Delta) || ready.contains(.Learn) {
			stateReady()
			output.forEach {
				$0.oClear()
			}
		}
		if ready.contains(.Delta) {
			ready.remove(.Delta)
		}
		if ready.contains(.Learn) {
			ready.remove(.Learn)
		}
		leave()
	}
	public func refresh() {

		const.deviation = unit.exp(0.5*const.logvariance, event: const.event)
		assert(const.deviation.status==LA_SUCCESS)
		
		const.variance = const.deviation * const.deviation
		assert(const.variance.status==LA_SUCCESS)
		
		const.value = const.mean// + const.deviation * unit.normal(rows: width, cols: 1, event: const.event)
		assert(const.value.status==LA_SUCCESS)

	}
}
extension Cell {
	private func collect() {
		if ready.contains(.State) {
		
		} else {
			enter()
			var waits: [dispatch_group_t] = [const.event]
			potential.value = const.value
			potential.mean = const.mean
			potential.variance = const.variance
			input.forEach {
				$0.input.collect()
				potential.value = potential.value + la_matrix_product($0.weight.value, $0.input.state.value)
				potential.mean = potential.mean + la_matrix_product($0.weight.mean, $0.input.state.value)
				potential.variance = potential.variance + la_matrix_product($0.weight.variance, $0.input.state.value * $0.input.state.value)
				waits.append($0.input.state.event)
				waits.append($0.weight.event)
			}
			state.value = unit.step(potential.value, waits: waits, event: state.event)
			leave()
		}
	}
	public func correct(let eps eps: Float) {
		if ready.contains(.Delta) {
		
		} else {
			enter()
			var waits: [dispatch_group_t] = [state.event]
			if ready.contains(.Learn) {
				collect()
				error.value = desired.value - state.value
			} else {
				error.value = la_splat_from_float(0, Cell.ATTR)
				output.forEach { ( let edge: Edge ) in
					edge.output.correct(eps: eps)
					error.value = error.value + la_matrix_product(la_transpose(edge.weight.value), edge.output.delta.value)
					
					edge.willChangeValueForKey("mean")
					edge.weight.mean = edge.weight.mean + eps * la_outer_product(edge.output.delta.value, state.value)
					edge.didChangeValueForKey("mean")
					
					waits.append(edge.output.delta.event)
					print("\(label), \(edge.weight.mean.eval)")
				}
			}
			delta.value = unit.sign(error.value, waits: waits, event: delta.event)
			
			const.mean = const.mean + eps * delta.value
			ready.insert(.Delta)
			leave()
		}
	}
	private func enter() {
		ready.insert(.Visit)
	}
	private func leave() {
		ready.remove(.Visit)
	}
	private var visited: Bool {
		return ready.contains(.Visit)
	}
	func constReady() {
		const.event.wait()
	}
	func stateReady() {
		state.event.wait()
	}
	func deltaReady() {
		delta.event.wait()
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
			stateReady()
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
	func setup() {
		let count: Int = Int(width)
		if let data: NSData = primitiveValueForKey("mean")?.mutableCopy()as?NSData {
			setPrimitiveValue(data, forKey: "mean")
			assert(mean.length==sizeof(Float)*count)
			const.mean = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(mean.bytes), width, 1, 1, Cell.HINT, nil, Cell.ATTR)
			assert(const.mean.status==LA_SUCCESS)
		} else {
			assertionFailure()
		}
		if let data: NSData = primitiveValueForKey("logvariance")?.mutableCopy()as?NSData {
			setPrimitiveValue(data, forKey: "logvariance")
			assert(logvariance.length==sizeof(Float)*count)
			const.logvariance = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(logvariance.bytes), width, 1, 1, Cell.HINT, nil, Cell.ATTR)
			assert(const.logvariance.status==LA_SUCCESS)
		} else {
			assertionFailure()
		}
	}
	public subscript(let index: UInt) -> Float {
		get {
			assert(index<width)
			let buffer: [Float] = [Float](count: Int(width), repeatedValue: 0)
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), 1, const.mean)
			return buffer[Int(index)]
		}
		set {
			assert(sizeof(Float)*Int(index)<mean.length)
			willChangeValueForKey("mean")
			UnsafeMutablePointer<Float>(mean.bytes).advancedBy(Int(index)).memory = newValue
			didChangeValueForKey("mean")
		}
	}
	func sync() {
		delta.event.wait()
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(mean.bytes), 1, const.mean)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(logvariance.bytes), 1, const.logvariance)
	}
	public override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
		refresh()
	}
	public override func awakeFromSnapshotEvents(flags: NSSnapshotEventType) {
		super.awakeFromSnapshotEvents(flags)
		setup()
		refresh()
	}
}
extension Context {
	public func newCell ( let width size: UInt, let label: String = "", let recur: Bool = false, let input: [Cell] = [] ) -> Cell? {
		let cell: Cell? = new()
		let width: UInt = ((size-1)/4+1)*4
		//size//max( size + 0x0f - ( ( size + 0x0f ) % 0x10 ), 0x10 )
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
				if input.managedObjectContext === self, let edge: Edge = new() {
					let count: Int = Int(cell.width * input.width)
					edge.input = input
					edge.output = cell
					edge.mean = NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count)
					edge.logvariance = NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count)
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
			}
		}
	}
}
extension NSData {
	var buffer: [Float] {
		let buffer: [Float] = [Float](count: length/sizeof(Float), repeatedValue: 0)
		getBytes(UnsafeMutablePointer<Void>(buffer))
		return buffer
	}
}