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
	private var weight = (
		value: la_splat_from_float(0, ATTR),
		mean: la_splat_from_float(0, ATTR),
		deviation: la_splat_from_float(0, ATTR),
		variance: la_splat_from_float(0, ATTR),
		logvariance: la_splat_from_float(0, ATTR)
	)
}
extension Edge {
	@NSManaged private var mean: NSData
	@NSManaged private var logvariance: NSData
	@NSManaged private var input: Cell
	@NSManaged private var output: Cell
}
extension Edge {
	override func awakeFromFetch() {
		super.awakeFromFetch()
		load()
	}
}
extension Edge {
	private func refresh() {
		weight.deviation = exp(0.5*weight.logvariance)
		weight.variance = weight.deviation * weight.deviation
		weight.value = weight.mean + weight.deviation * normal(rows: output.width, cols: input.width)
	}
	private func forget() {
	
	}
	internal func iClear() {
		refresh()
		input.iClear()
	}
	internal func oClear() {
		forget()
		output.oClear()
	}
	internal func sync() {
		
		let buffer: [Float] = [Float](count: Int(output.width*input.width), repeatedValue: 0)
		
		assert(buffer.count==weight.mean.count)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), input.width, weight.mean)
		let mean = NSData(bytes: buffer, length: sizeof(Float)*buffer.count)
		
		assert(buffer.count==weight.logvariance.count)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), input.width, weight.logvariance)
		let logvariance = NSData(bytes: buffer, length: sizeof(Float)*buffer.count)
		
		weight.mean = la_matrix_from_float_buffer(UnsafePointer<Float>(mean.bytes), output.width, input.width, input.width, Edge.HINT, Edge.ATTR)
		weight.logvariance = la_matrix_from_float_buffer(UnsafePointer<Float>(logvariance.bytes), output.width, input.width, input.width, Edge.HINT, Edge.ATTR)
		
		managedObjectContext?.performBlockAndWait {
			self.mean = mean
			self.logvariance = logvariance
		}
	}
	internal func load() {
		weight.mean = la_matrix_from_float_buffer(UnsafePointer<Float>(mean.bytes), output.width, input.width, input.width, Edge.HINT, Edge.ATTR)
		weight.logvariance = la_matrix_from_float_buffer(UnsafePointer<Float>(logvariance.bytes), output.width, input.width, input.width, Edge.HINT, Edge.ATTR)
		refresh()
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
	internal func collect() -> (la_object_t, la_object_t, la_object_t) {
		let state: la_object_t = input.collect()
		let value: la_object_t = la_matrix_product(weight.value, state)
		let mean: la_object_t = la_matrix_product(weight.mean, state)
		let variance: la_object_t = la_matrix_product(weight.variance, state * state)
		return (value, mean, variance)
	}
	internal func correct(let eps eps: Float) -> la_object_t {
		let(mean, variance) = output.correct(eps: eps)
		
		let state: la_object_t = input.collect()
		let delta: la_object_t = la_matrix_product(la_transpose(weight.value), mean)
		
		weight.mean = weight.mean + eps * la_outer_product(mean, state)
		weight.variance = weight.variance - eps * 0.5 * weight.variance * la_outer_product(variance, state*state)
		
		sync()
		
		return delta
	}
}
