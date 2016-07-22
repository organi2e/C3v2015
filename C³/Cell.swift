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
	private enum Status {
		case READY
		case ERROR
		case IDEAL
		case VISIT
	}
	private var status: Set<Status> = Set<Status>()
	private var values = (
		state: la_splat_from_float(0, ATTR),
		value: la_splat_from_float(0, ATTR),
		ideal: la_splat_from_float(0, ATTR),
		error: la_splat_from_float(0, ATTR),
		const: la_splat_from_float(0, ATTR)
	)
	private var elders = (
		state: la_splat_from_float(0, ATTR),
		value: la_splat_from_float(0, ATTR)
	)
	private var groups = (
		state: dispatch_group_create(),
		error: dispatch_group_create(),
		const: dispatch_group_create()
	)
	private var statistics = (
		mean: la_splat_from_float(0, ATTR),
		deviation: la_splat_from_float(0, ATTR),
		variance: la_splat_from_float(0, ATTR)
	)
	private var estimated = (
		mean: la_splat_from_float(0, ATTR),
		deviation: la_splat_from_float(1, ATTR),
		lambda: la_splat_from_float(0, ATTR)
	)
}
extension Cell {
	@NSManaged public private(set) var label: String
	@NSManaged public private(set) var width: UInt
	@NSManaged public var attribute: [String: AnyObject]
	@NSManaged private var mean: NSData
	@NSManaged private var deviation: NSData
	@NSManaged private var lambda: NSData
	@NSManaged private var input: Set<Edge>
	@NSManaged private var output: Set<Edge>
}
extension Cell {
	public func iClear() {
		if !visited {
			enter()
			
			if status.contains(.READY) {
				status.remove(.READY)
				
				values.const = unit.normal(rows: width, cols: 1, event: groups.const)
				assert(values.const.status==LA_SUCCESS)
				
				/*
				values.value = la_splat_from_float(0, Cell.ATTR)
				assert(values.value.status==LA_SUCCESS)
				
				values.state = la_splat_from_float(0, Cell.ATTR)
				assert(values.state.status==LA_SUCCESS)
				
				statistics.mu = la_splat_from_float(0, Cell.ATTR)
				assert(statistics.mu.status==LA_SUCCESS)
				
				statistics.sigma = la_splat_from_float(1, Cell.ATTR)
				assert(statistics.sigma.status==LA_SUCCESS)
				*/
				input.forEach {
					$0.iClear()
				}
			}
			leave()
		}
	}
	public func oClear() {
		if !visited {
			enter()
			if status.contains(.ERROR) || status.contains(.IDEAL) {
				output.forEach {
					$0.oClear()
				}
			}
			if status.contains(.ERROR) {
				status.remove(.ERROR)
				values.error = la_splat_from_float(0, Cell.ATTR)
			}
			if status.contains(.IDEAL) {
				status.remove(.IDEAL)
				values.ideal = la_splat_from_float(0, Cell.ATTR)
			}
			leave()
		}
	}
	public func refresh() {
		let zero: la_object_t = la_splat_from_float(0, Cell.ATTR)
		
		values.const = estimated.mean + estimated.deviation * unit.normal(rows: width, cols: 1, event: groups.const)
		assert(values.const.status==LA_SUCCESS)
		
		values.ideal = la_matrix_from_splat(zero, la_count_t(width), la_count_t(1))
		values.error = la_matrix_from_splat(zero, la_count_t(width), la_count_t(1))
		
		values.state = la_matrix_from_splat(zero, la_count_t(width), la_count_t(1))
		values.value = la_matrix_from_splat(zero, la_count_t(width), la_count_t(1))
		
		elders.state = la_matrix_from_splat(zero, la_count_t(width), la_count_t(1))
		elders.value = la_matrix_from_splat(zero, la_count_t(width), la_count_t(1))

		
	}
	public func correct(let eps eps: Float) {
		
	}
}
extension Cell {
	func collect() {
		if !status.contains(.READY) {
			enter()
			
			var waits: [dispatch_group_t] = [groups.const]
			var accum: la_object_t = values.const
				
			input.forEach {
				if $0.input.visited {
					accum = accum + la_matrix_product($0.values, $0.input.elders.state)
				} else {
					$0.input.collect()
					accum = accum + la_matrix_product($0.values, $0.input.values.state)
					waits.append($0.input.groups.state)
				}
				waits.append($0.groups)
			}
			
			values.value = accum
			values.state = unit.step(values.value, waits: waits, event: groups.state)
			
			status.insert(.READY)
			leave()
		}
	}
	func backward() {
		
	}
	func enter() {
		status.insert(.VISIT)
	}
	func leave() {
		status.remove(.VISIT)
	}
	var visited: Bool {
		return status.contains(.VISIT)
	}
	
}
extension Cell {
	var state: [Bool] {
		set {
			assert(width==UInt(newValue.count))
			values.state = la_matrix_from_float_buffer(newValue.map{Float($0)}, la_count_t(width), la_count_t(1), la_count_t(1), Cell.HINT, Cell.ATTR)
			assert(values.state.status==LA_SUCCESS)
			status.insert(.READY)
		}
		get {
			collect()
			groups.state.wait()
			let cache: [Float] = [Float](count: Int(width), repeatedValue: 0)
			assert(la_vector_length(values.state)==width)
			assert(la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(1), values.state)==0)
			return cache.map{Bool($0)}
		}
	}
	var ideal: [Bool] {
		set {
			assert(width==UInt(newValue.count))
			values.ideal = la_matrix_from_float_buffer(newValue.map{Float($0)}, la_count_t(width), la_count_t(1), la_count_t(1), Cell.HINT, Cell.ATTR)
			assert(values.ideal.status==LA_SUCCESS)
			status.insert(.IDEAL)
		}
		get {
			let cache: [Float] = [Float](count: Int(width), repeatedValue: 0)
			assert(la_vector_length(values.ideal)==width)
			assert(la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(1), values.ideal)==0)
			return cache.map{Bool($0)}
		}
	}
}
extension Cell {
	func setup() {
		let count: Int = Int(width)
		assert(mean.length==sizeof(Float)*count)
		estimated.mean = la_matrix_from_float_buffer(UnsafePointer<Float>(mean.bytes), la_count_t(width), la_count_t(1), la_count_t(1), Cell.HINT, Cell.ATTR)
		assert(estimated.mean.status==LA_SUCCESS)
		
		assert(deviation.length==sizeof(Float)*count)
		estimated.deviation = la_matrix_from_float_buffer(UnsafePointer<Float>(deviation.bytes), la_count_t(width), la_count_t(1), la_count_t(1), Cell.HINT, Cell.ATTR)
		assert(estimated.deviation.status==LA_SUCCESS)
		
		assert(lambda.length==sizeof(Float)*count)
		estimated.lambda = la_matrix_from_float_buffer(UnsafePointer<Float>(lambda.bytes), la_count_t(width), la_count_t(1), la_count_t(1), Cell.HINT, Cell.ATTR)
		assert(estimated.lambda.status==LA_SUCCESS)
		
		refresh()
		
	}
	public override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
	public override func awakeFromSnapshotEvents(flags: NSSnapshotEventType) {
		super.awakeFromSnapshotEvents(flags)
		setup()
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
			cell.deviation = NSData(bytes: [Float](count: count, repeatedValue: 1.0), length: sizeof(Float)*count)
			cell.lambda = NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count)
			cell.setup()
			input.forEach { ( let input: Cell ) in
				if input.managedObjectContext === self, let edge: Edge = new() {
					let count: Int = Int(cell.width * input.width)
					edge.input = input
					edge.output = cell
					edge.mean = NSData(bytes: [Float](count: count, repeatedValue: 0.0), length: sizeof(Float)*count)
					edge.deviation = NSData(bytes: [Float](count: count, repeatedValue: 1.0), length: sizeof(Float)*count)
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
		
	}
}