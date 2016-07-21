//
//  Cell.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import Accelerate
import CoreData
import NLA

public class Cell: C3Object {
	private enum Status {
		case READY
		case ERROR
		case IDEAL
	}
	private var status: Set<Status> = Set<Status>()
	private var values = (
		state: la_splat_from_float(0, ATTR),
		value: la_splat_from_float(0, ATTR),
		ideal: la_splat_from_float(0, ATTR),
		error: la_splat_from_float(0, ATTR),
		const: la_splat_from_float(0, ATTR)
	)
	private var groups = (
		state: dispatch_group_create(),
		error: dispatch_group_create(),
		const: dispatch_group_create()
	)
	private var statistics = (
		mu: la_splat_from_float(0, ATTR),
		sigma: la_splat_from_float(0, ATTR)
	)
	private var estimated = (
		mean: la_splat_from_float(0, ATTR),
		variance: la_splat_from_float(1, ATTR),
		lambda: la_splat_from_float(0, ATTR)
	)
}
extension Cell {
	@NSManaged public private(set) var label: String
	@NSManaged public private(set) var width: Int
	@NSManaged public var attribute: [String: AnyObject]
	@NSManaged private var mean: NSData
	@NSManaged private var variance: NSData
	@NSManaged private var lambda: NSData
	@NSManaged private var input: Set<Edge>
	@NSManaged private var output: Set<Edge>
}
extension Cell {
	public func iClear() {
		if status.contains(.READY) {
			input.forEach {
				$0.iClear()
			}
		}
	}
	public func oClear() {
		if status.contains(.ERROR) || status.contains(.IDEAL) {
			output.forEach {
				$0.oClear()
			}
		}
	}
	public func clear ( ) {
		func parent( let cell: Cell ) {
			if cell.status.contains(.ERROR) {
				cell.values.error = la_splat_from_float(0, Cell.ATTR)
				cell.status.remove(.ERROR)
			}
			if cell.status.contains(.IDEAL) {
				cell.values.ideal = la_splat_from_float(0, Cell.ATTR)
				cell.status.remove(.IDEAL)
			}
			cell.output.forEach {
				parent($0.output)
			}
		}
		parent(self)
		func child( let cell: Cell ) {
			if cell.status.contains(.READY) {
				cell.values.value = la_splat_from_float(0, Cell.ATTR)
				cell.values.state = la_splat_from_float(0, Cell.ATTR)
				cell.statistics.mu = la_splat_from_float(0, Cell.ATTR)
				cell.statistics.sigma = la_splat_from_float(0, Cell.ATTR)
				cell.status.remove(.READY)
			}
			cell.values.const = estimated.mean + estimated.variance * unit.normal(rows: width, cols: 1)
			cell.input.forEach {
				child($0.input)
			}
		}
		child(self)
	}
	public func correct(let eps eps: Float) {
	
	}
}
extension Cell {
	func collect() {
		if !status.contains(.READY) {
			
		}
	}
	func backward() {
		
	}
}
extension Cell {
	var state: [Bool] {
		set {
			assert(width==newValue.count)
			values.state = la_matrix_from_float_buffer(newValue.map{Float($0)}, la_count_t(width), la_count_t(1), la_count_t(1), Cell.HINT, Cell.ATTR)
			status.insert(.READY)
		}
		get {
			collect()
			let cache: [Float] = [Float](count: width, repeatedValue: 0)
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(1), values.state)
			return cache.map{Bool($0)}
		}
	}
	var ideal: [Bool] {
		set {
			assert(width==newValue.count)
			collect()
			values.ideal = la_matrix_from_float_buffer(newValue.map{Float($0)}, la_count_t(width), la_count_t(1), la_count_t(1), Cell.HINT, Cell.ATTR)
			status.insert(.IDEAL)
		}
		get {
			let cache: [Float] = [Float](count: width, repeatedValue: 0)
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(1), values.ideal)
			return cache.map{Bool($0)}
		}
	}
}
extension Cell {
	func setup() {
		
		assert(mean.length==sizeof(Float)*width)
		assert(variance.length==sizeof(Float)*width)
		assert(lambda.length==sizeof(Float)*width)
		
		estimated.mean = la_matrix_from_float_buffer(UnsafePointer<Float>(mean.bytes), la_count_t(width), la_count_t(1), la_count_t(1), Cell.HINT, Cell.ATTR)
		estimated.variance = la_matrix_from_float_buffer(UnsafePointer<Float>(variance.bytes), la_count_t(width), la_count_t(1), la_count_t(1), Cell.HINT, Cell.ATTR)
		estimated.lambda = la_matrix_from_float_buffer(UnsafePointer<Float>(lambda.bytes), la_count_t(width), la_count_t(1), la_count_t(1), Cell.HINT, Cell.ATTR)
		
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
	public func newCell ( let width size: Int, let label: String = "", let recur: Bool = false, let input: [Cell] = [] ) -> Cell? {
		let cell: Cell? = new()
		let width: Int = size//max( size + 0x0f - ( ( size + 0x0f ) % 0x10 ), 0x10 )
		if let cell: Cell = cell {
			cell.width = width
			cell.label = label
			cell.attribute = [:]
			cell.mean = NSData(bytes: [Float](count: width, repeatedValue: 0.0), length: sizeof(Float)*width)
			cell.variance = NSData(bytes: [Float](count: width, repeatedValue: 0.0), length: sizeof(Float)*width)
			cell.lambda = NSData(bytes: [Float](count: width, repeatedValue: 0.0), length: sizeof(Float)*width)
			cell.setup()
			input.forEach { ( let input: Cell ) in
				if input.managedObjectContext === self, let edge: Edge = new() {
					edge.input = input
					edge.output = cell
					edge.mean = NSData(bytes: [Float](count: cell.width*input.width, repeatedValue: 0.0), length: sizeof(Float)*cell.width*input.width)
					edge.variance = NSData(bytes: [Float](count: cell.width*input.width, repeatedValue: 0.0), length: sizeof(Float)*cell.width*input.width)
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