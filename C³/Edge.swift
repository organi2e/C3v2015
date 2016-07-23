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
	@NSManaged var mean: NSMutableData
	@NSManaged var logvariance: NSMutableData
	@NSManaged var input: Cell
	@NSManaged var output: Cell
}
extension Edge {
	func dump() {
		print("mean la: \(weight.mean.eval)")
		print("mean data: \(mean.buffer)")
		print("logvariance: \(weight.logvariance.eval)")
	}
	func setup() {
		let rows: UInt = output.width
		let cols: UInt = input.width
		let count: Int = Int(rows * cols)

		if let data: NSMutableData = primitiveValueForKey("mean")?.mutableCopy()as?NSMutableData {
			setPrimitiveValue(data, forKey: "mean")
			assert(mean.length==sizeof(Float)*count)
			weight.mean = la_matrix_from_float_buffer(UnsafeMutablePointer<Float>(mean.mutableBytes), rows, cols, cols, Edge.HINT, Edge.ATTR)
			assert(weight.mean.status==LA_SUCCESS)
		} else {
			assertionFailure()
		}
		if let data: NSMutableData = primitiveValueForKey("logvariance")?.mutableCopy()as?NSMutableData {
			setPrimitiveValue(data, forKey: "logvariance")
			assert(logvariance.length==sizeof(Float)*count)
			weight.logvariance = la_matrix_from_float_buffer(UnsafeMutablePointer<Float>(logvariance.mutableBytes), rows, cols, cols, Edge.HINT, Edge.ATTR)
			assert(weight.variance.status==LA_SUCCESS)
		} else {
			assertionFailure()
		}
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
	override func willSave() {
		super.willSave()
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(mean.mutableBytes), input.width, weight.mean)
		dump()
	}
	override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
		dump()
	}
	override func awakeFromSnapshotEvents(flags: NSSnapshotEventType) {
		super.awakeFromSnapshotEvents(flags)
		setup()
		dump()
	}
}