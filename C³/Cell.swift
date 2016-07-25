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
	static let ATTR: la_attribute_t = la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)
	static let HINT: la_hint_t = la_hint_t(LA_NO_HINT)
	private enum Ready {
		case State
		case Delta
		case Learn
	}
	private var ready: Set<Ready> = Set<Ready>()
	internal var delta = (
		mean: la_splat_from_float(0, ATTR),
		variance: la_splat_from_float(0, ATTR)
		//event: dispatch_group_create()
	)
	internal var error = (
		mean: la_splat_from_float(0, ATTR),
		//variance: la_splat_from_float(1, ATTR),
		event: dispatch_group_create()
	)
	internal var desired = (
		value: la_splat_from_float(0, ATTR),
		mean: la_splat_from_float(0, ATTR),
		variance: la_splat_from_float(1, ATTR)
	)
	internal var state = (
		value: la_splat_from_float(0, ATTR),
		probably: la_splat_from_float(0, ATTR)//,
		//event: dispatch_group_create()
	)
	internal var potential = (
		value: la_splat_from_float(0, ATTR),
		mean: la_splat_from_float(0, ATTR),
		variance: la_splat_from_float(1, ATTR)
	)
	internal var const = (
		value: la_splat_from_float(0, ATTR),
		mean: la_splat_from_float(0, ATTR),
		deviation: la_splat_from_float(1, ATTR),
		variance: la_splat_from_float(1, ATTR),
		logvariance: la_splat_from_float(0, ATTR)//,
		//event: dispatch_group_create()
	)
}
extension Cell {
	private static let meankey: String = "mean"
	private static let logvariance: String = "logvariance"
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
		const.mean = la_matrix_from_float_buffer(UnsafePointer<Float>(mean.bytes), width, 1, 1, Cell.HINT, Cell.ATTR)
		const.logvariance = la_matrix_from_float_buffer(UnsafePointer<Float>(logvariance.bytes), width, 1, 1, Cell.HINT, Cell.ATTR)
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
}
extension Cell {
	func refresh() {
		
		const.deviation = exp(0.5*const.logvariance)
		const.variance = const.deviation * const.deviation
		const.value = const.mean + const.deviation * normal(rows: width, cols: 1)
		
		potential.mean = const.mean
		potential.variance = const.variance
		potential.value = const.value
		
	}
	func iClear() {
		if ready.contains(.State) {
			ready.remove(.State)
			
			refresh()
			input.forEach {
				$0.refresh()
				$0.input.iClear()
			}
		}
	}
	func oClear() {
		if ready.contains(.Delta) {
			ready.remove(.Delta)
			ready.remove(.Learn)
			
			output.forEach {
				$0.output.oClear()
			}
		}
	}
	func collect() {
		if ready.contains(.State) {
			
		} else {
			do {
				ready.insert(.State)
				
				potential.value = const.value
				potential.mean = const.mean
				potential.variance = const.variance
				
				input.forEach {
					
					$0.input.collect()
				
					potential.value = potential.value + la_matrix_product($0.weight.value, $0.input.state.value)
					potential.mean = potential.mean + la_matrix_product($0.weight.mean, $0.input.state.value)
					potential.variance = potential.variance + la_matrix_product($0.weight.variance, $0.input.state.value * $0.input.state.value)
				
				}
				state.value = step(potential.value)
			}
		}
	}
	func correct(let eps eps: Float) {
		if ready.contains(.Delta) {
		
		} else {
			ready.insert(.Delta)
			if ready.contains(.Learn) {
				collect()
				error.mean = desired.value - state.value
			} else {
				error.mean = la_splat_from_float(0, Cell.ATTR)
				
				output.forEach {
					$0.output.correct(eps: eps)

					error.mean = error.mean + la_matrix_product(la_transpose($0.weight.value), $0.output.delta.mean)
			
					$0.weight.mean = $0.weight.mean + eps * la_outer_product($0.output.delta.mean, state.value)
					$0.weight.logvariance = $0.weight.logvariance - eps * 0.5 * $0.weight.variance * (la_outer_product($0.output.delta.variance, state.value * state.value))
					$0.save()
					$0.load()
				}
			}
			delta.mean = pdf(x: la_splat_from_float(0, Cell.ATTR), mu: potential.value, sigma: sqrt(potential.variance)) * sign(error.mean)
			delta.variance = delta.mean * potential.mean / potential.variance
			
			const.mean = const.mean + eps * delta.mean
			const.logvariance = const.logvariance - eps * 0.5 * const.variance * delta.variance
			save()
			load()
		}
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
			cell.load()
			cell.refresh()
			input.forEach { ( let input: Cell ) in
				if input.managedObjectContext === self, let edge: Edge = new() {
					let count: Int = Int(cell.width * input.width)
					edge.input = input
					edge.output = cell
					edge.mean = NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count)
					edge.logvariance = NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count)
					edge.load()
					edge.refresh()
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