//
//  Edge.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import Accelerate
import NLA
import CoreData

internal class Edge: C3Object {
	var estimated: (mean: la_object_t, variance: la_object_t) = (
		mean: la_splat_from_float(0, la_attribute_t(LA_DEFAULT_ATTRIBUTES)),
		variance: la_splat_from_float(0, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	)
	//var weight: la_object_t = la_splat_from_float(0, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	var values = (
		weight: la_splat_from_float(0, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	)
	var groups = (
		weight: dispatch_group_create()
	)
}
extension Edge {
	@NSManaged var mean: NSData
	@NSManaged var variance: NSData
	@NSManaged var input: Cell
	@NSManaged var output: Cell
}
extension Edge {
	func setup() {
		let rows: Int = output.width
		let cols: Int = input.width
		let count: Int = rows * cols
		
		assert(mean.length==sizeof(Float)*count)
		assert(variance.length==sizeof(Float)*count)
		
		estimated.mean = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(mean.bytes), la_count_t(rows), la_count_t(cols), la_count_t(cols), la_hint_t(LA_NO_HINT), nil, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
		estimated.variance = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(variance.bytes), la_count_t(rows), la_count_t(cols), la_count_t(cols), la_hint_t(LA_NO_HINT), nil, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	}
	func oClear() {
		output.oClear()
	}
	func iClear() {
		input.iClear()
	}
	func clear() {
		let rows: Int = output.width
		let cols: Int = input.width
		values = la_sum(estimated.mean, la_elementwise_product(estimated.variance, unit.normal(rows: rows, cols: cols, event: groups)))
	}
	func ready() {
		groups.wait()
	}
	func sync() {
		let rows: Int = output.width
		let cols: Int = input.width
		
		assert(mean.length==sizeof(Float)*rows*cols)
		assert(variance.length==sizeof(Float)*rows*cols)
		
		willChangeValueForKey("mean")
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(mean.bytes), la_count_t(cols), estimated.mean)
		didChangeValueForKey("mean")
		
		willChangeValueForKey("variance")
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(variance.bytes), la_count_t(cols), estimated.variance)
		didChangeValueForKey("variance")
	}
	override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
	override func awakeFromSnapshotEvents(flags: NSSnapshotEventType) {
		super.awakeFromSnapshotEvents(flags)
		setup()
	}
}