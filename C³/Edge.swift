//
//  Edge.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import Accelerate
import NLA

internal class Edge: NSManagedObject {
	static let ATTR: la_attribute_t = la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)
	static let HINT: la_hint_t = la_hint_t(LA_NO_HINT)
	var weight = (
		value: la_splat_from_float(0, ATTR),
		mean: la_splat_from_float(0, ATTR),
		deviation: la_splat_from_float(0, ATTR),
		variance: la_splat_from_float(0, ATTR),
		logvariance: la_splat_from_float(0, ATTR)
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
	override func awakeFromFetch() {
		super.awakeFromFetch()
		load()
		refresh()
	}
}
extension Edge {
	internal func refresh() {
		weight.deviation = exp(0.5*weight.logvariance)
		weight.variance = weight.deviation * weight.deviation
		weight.value = weight.mean + weight.deviation * normal(rows: output.width, cols: input.width)
	}
	internal func forget() {
	
	}
	internal func sync() {
		
		let buffer: [Float] = [Float](count: Int(output.width*input.width), repeatedValue: 0)
		
		assert(buffer.count==weight.mean.count)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), input.width, weight.mean)
		mean = NSData(bytes: buffer, length: sizeof(Float)*buffer.count)
		
		assert(buffer.count==weight.logvariance.count)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), input.width, weight.logvariance)
		logvariance = NSData(bytes: buffer, length: sizeof(Float)*buffer.count)
		
		weight.mean = la_matrix_from_float_buffer(UnsafePointer<Float>(mean.bytes), output.width, input.width, input.width, Edge.HINT, Edge.ATTR)
		weight.logvariance = la_matrix_from_float_buffer(UnsafePointer<Float>(logvariance.bytes), output.width, input.width, input.width, Edge.HINT, Edge.ATTR)
		
	}
	internal func load() {
		weight.mean = la_matrix_from_float_buffer(UnsafePointer<Float>(mean.bytes), output.width, input.width, input.width, Edge.HINT, Edge.ATTR)
		weight.logvariance = la_matrix_from_float_buffer(UnsafePointer<Float>(logvariance.bytes), output.width, input.width, input.width, Edge.HINT, Edge.ATTR)
	}
	internal func save() {
		let buffer: [Float] = [Float](count: Int(output.width*input.width), repeatedValue: 0)
		
		assert(buffer.count==weight.mean.count)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), input.width, weight.mean)
		mean = NSData(bytes: buffer, length: sizeof(Float)*buffer.count)
		
		assert(buffer.count==weight.logvariance.count)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), input.width, weight.logvariance)
		logvariance = NSData(bytes: buffer, length: sizeof(Float)*buffer.count)
	}
}
