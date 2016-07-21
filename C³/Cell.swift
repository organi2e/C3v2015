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

public class Cell: NSManagedObject {
	private enum Status {
		case READY
		case ERROR
		case IDEAL
	}
	private struct AsyncValue {
		var value: la_object_t
		let event: dispatch_group_t
		init() {
			value = la_splat_from_float(0, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
			event = dispatch_group_create()
		}
		func ready() {
			dispatch_group_wait(event, DISPATCH_TIME_FOREVER)
		}
	}
	private struct Statistics {
		var mu: la_object_t
		var sigma: la_object_t
	}
	private struct Estimated {
		var mean: la_object_t
		var variance: la_object_t
		var lambda: la_object_t
	}
	private var status: Set<Status> = Set<Status>()
	private var values = (
		state: LA(row: 1, col: 1),
		value: la_splat_from_float(0, LA.ATTR),
		ideal: LA(row: 1, col: 1),
		error: la_splat_from_float(0, LA.ATTR),
		gauss: LA(row: 1, col: 1)
	)
	private var statistics: Statistics = Statistics(
		mu: la_splat_from_float(0, LA.ATTR),
		sigma: la_splat_from_float(0, LA.ATTR)
	)
	private var estimated = (
		mean: la_splat_from_float(0, LA.ATTR),
		variance: la_splat_from_float(1, LA.ATTR),
		lambda: la_splat_from_float(0, LA.ATTR)
	)
	private var C: AsyncValue = AsyncValue()
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
	public func clear ( ) {
		guard let context: Context = managedObjectContext as? Context else { assertionFailure(); return }
		func parent( let cell: Cell ) {
			if cell.status.contains(.ERROR) {
				cell.values.error = la_splat_from_float(0, LA.ATTR)
				cell.status.remove(.ERROR)
			}
			if cell.status.contains(.IDEAL) {
				cell.values.ideal.clear()
				cell.status.remove(.IDEAL)
			}
			cell.output.forEach {
				parent($0.output)
			}
		}
		parent(self)
		func child( let cell: Cell ) {
			if cell.status.contains(.READY) {
				cell.values.value = la_splat_from_float(0, LA.ATTR)
				cell.values.state.clear()
				cell.statistics.mu = la_splat_from_float(0, LA.ATTR)
				cell.statistics.sigma = la_splat_from_float(0, LA.ATTR)
				cell.status.remove(.READY)
			}
			cell.values.gauss.normal()
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
			values.state.fill(newValue.map{Float($0)})
			status.insert(.READY)
		}
		get {
			collect()
			return values.state.buffer.map{Bool($0)}
		}
	}
	var ideal: [Bool] {
		set {
			assert(width==newValue.count)
			values.ideal.fill(newValue.map{Float($0)})
			status.insert(.ERROR)
		}
		get {
			return values.ideal.buffer.map{Bool($0)}
		}
	}
}
extension Cell {
	func setup() {
		
		values.ideal = LA(row: width, col: 1)
		values.state = LA(row: width, col: 1)
		values.gauss = LA(row: width, col: 1)
		
		estimated.mean = la_matrix_from_float_buffer(UnsafePointer<Float>(mean.bytes), la_count_t(width), la_count_t(1), la_count_t(1), LA.HINT, LA.ATTR)
		estimated.variance = la_matrix_from_float_buffer(UnsafePointer<Float>(variance.bytes), la_count_t(width), la_count_t(1), la_count_t(1), LA.HINT, LA.ATTR)
		estimated.lambda = la_matrix_from_float_buffer(UnsafePointer<Float>(lambda.bytes), la_count_t(width), la_count_t(1), la_count_t(1), LA.HINT, LA.ATTR)
		
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