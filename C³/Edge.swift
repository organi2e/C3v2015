//
//  Edge.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import Accelerate
import NLA

internal class Edge: C3Object {
	var estimated = (
		mean: la_splat_from_float(0, ATTR),
		deviation: la_splat_from_float(0, ATTR)
	)
	var values = (
		weight: la_splat_from_float(0, ATTR)
	)
	var groups = (
		weight: dispatch_group_create()
	)
}
extension Edge {
	@NSManaged var mean: NSData
	@NSManaged var deviation: NSData
	@NSManaged var input: Cell
	@NSManaged var output: Cell
}
extension Edge {
	func setup() {
		let rows: UInt = output.width
		let cols: UInt = input.width
		let count: Int = Int(rows * cols)
		
		assert(mean.length==sizeof(Float)*count)
		estimated.mean = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(mean.bytes), la_count_t(rows), la_count_t(cols), la_count_t(cols), Edge.HINT, nil, Edge.ATTR)
		assert(estimated.mean.status==LA_SUCCESS)

		assert(deviation.length==sizeof(Float)*count)
		estimated.deviation = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(deviation.bytes), la_count_t(rows), la_count_t(cols), la_count_t(cols), Edge.HINT, nil, Edge.ATTR)
		assert(estimated.deviation.status==LA_SUCCESS)
		
		values = estimated.mean + estimated.deviation * unit.normal(rows: rows, cols: cols, event: groups)
		assert(values.status==LA_SUCCESS)
		groups.wait()
	}
	func oClear() {
		output.oClear()
	}
	func iClear() {
		let rows: UInt = output.width
		let cols: UInt = input.width
		
		values = estimated.mean + estimated.deviation * unit.normal(rows: rows, cols: cols, event: groups)
		assert(values.status==LA_SUCCESS)
		groups.wait()
		
		input.iClear()
	}
	func sync() {
		let rows: UInt = output.width
		let cols: UInt = input.width
		let count: Int = Int(rows*cols)
		
		assert(mean.length==sizeof(Float)*count)
		willChangeValueForKey("mean")
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(mean.bytes), la_count_t(cols), estimated.mean)
		didChangeValueForKey("mean")
		
		assert(deviation.length==sizeof(Float)*count)
		willChangeValueForKey("variance")
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(deviation.bytes), la_count_t(cols), estimated.deviation)
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