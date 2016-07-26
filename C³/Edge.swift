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
		setup()
	}
}
extension Edge {
	internal func setup() {
		managedObjectContext?.performBlockAndWait {
			if let data: NSData = self.primitiveValueForKey("mean")as?NSData {
				self.setPrimitiveValue(NSData(data: data), forKey: "mean")
			}
			if let data: NSData = self.primitiveValueForKey("logvariance")as?NSData {
				self.setPrimitiveValue(NSData(data: data), forKey: "logvariance")
			}
		}
		weight.mean = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(mean.bytes), output.width, input.width, input.width, Edge.HINT, nil, Edge.ATTR)
		weight.logvariance = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(logvariance.bytes), output.width, input.width, input.width, Edge.HINT, nil, Edge.ATTR)
		refresh()
	}
	internal func commit() {
		managedObjectContext?.performBlockAndWait {
			self.willChangeValueForKey("mean")
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(self.mean.bytes), self.input.width, self.weight.mean)
			self.didChangeValueForKey("mean")
			
			self.willChangeValueForKey("logvariance")
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(self.logvariance.bytes), self.input.width, self.weight.logvariance)
			self.didChangeValueForKey("logvariance")
		}
		weight.mean = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(mean.bytes), output.width, input.width, input.width, Edge.HINT, nil, Edge.ATTR)
		weight.logvariance = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(logvariance.bytes), output.width, input.width, input.width, Edge.HINT, nil, Edge.ATTR)
	}
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
		weight.logvariance = weight.logvariance - eps * 0.5 * weight.variance * la_outer_product(variance, state*state)
		
		commit()
		
		return delta
	}
}
