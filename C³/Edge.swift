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
	var weight = (
		value: la_splat_from_float(0, ATTR),
		mean: la_splat_from_float(0, ATTR),
		deviation: la_splat_from_float(0, ATTR),
		variance: la_splat_from_float(0, ATTR),
		logvariance: la_splat_from_float(0, ATTR),
		event: dispatch_group_create()
	)
}
extension Edge {
	@NSManaged var mean: NSData
	@NSManaged var logvariance: NSData
	@NSManaged var input: Cell
	@NSManaged var output: Cell
}
extension Edge {
	func dump() {
		print("mean: \(weight.mean.eval)")
		print("logvariance: \(weight.logvariance.eval)")
	}
	func setup() {
		let rows: UInt = output.width
		let cols: UInt = input.width
		let count: Int = Int(rows * cols)

		assert(mean.length==sizeof(Float)*count)
		weight.mean = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(mean.bytes), rows, cols, cols, Edge.HINT, nil, Edge.ATTR)
		assert(weight.mean.status==LA_SUCCESS)

		assert(logvariance.length==sizeof(Float)*count)
		weight.logvariance = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(logvariance.bytes), rows, cols, cols, Edge.HINT, nil, Edge.ATTR)
		assert(weight.variance.status==LA_SUCCESS)
		
		dump()
		refresh()
	}
	func refresh() {
		
		weight.deviation = unit.exp(0.5*weight.logvariance, event: weight.event)
		weight.variance = weight.deviation * weight.deviation
		weight.value = weight.mean// + weight.deviation * unit.normal(rows: output.width, cols: input.width, event: weight.event)
	}
	func oClear() {
		output.oClear()
	}
	func iClear() {
		refresh()
		input.iClear()
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