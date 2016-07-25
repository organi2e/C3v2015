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
	private static let meankey: String = "mean"
	private static let logvariancekey: String = "logvariance"
	@NSManaged var mean: NSData
	@NSManaged var logvariance: NSData
	@NSManaged var input: Cell
	@NSManaged var output: Cell
}
extension Edge {
	override func awakeFromInsert() {
		super.awakeFromInsert()
		setPrimitiveValue(NSData(), forKey: Edge.meankey)
		setPrimitiveValue(NSData(), forKey: Edge.logvariancekey)
	}
	override func awakeFromFetch() {
		super.awakeFromFetch()
		load()
	}
}
extension Edge {
	internal func refresh() {
		weight.deviation = unit.exp(0.5*weight.logvariance, event: weight.event)
		weight.variance = weight.deviation * weight.deviation
		weight.value = weight.mean + weight.deviation * unit.normal(rows: output.width, cols: input.width, event: weight.event)
	}
	internal func load() {
		weight.mean = la_matrix_from_float_buffer(UnsafePointer<Float>(mean.bytes), output.width, input.width, input.width, Edge.HINT, Edge.ATTR)
		weight.logvariance = la_matrix_from_float_buffer(UnsafePointer<Float>(logvariance.bytes), output.width, input.width, input.width, Edge.HINT, Edge.ATTR)
		refresh()
	}
	internal func save() {
		let buffer: [Float] = [Float](count: Int(output.width*input.width), repeatedValue: 0)
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), input.width, weight.mean)
		mean = NSData(bytes: buffer, length: sizeof(Float)*buffer.count)
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), input.width, weight.logvariance)
		logvariance = NSData(bytes: buffer, length: sizeof(Float)*buffer.count)
	}
}
