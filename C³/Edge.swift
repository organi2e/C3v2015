//
//  Edge.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import Accelerate
import CoreData

internal class Edge: NSManagedObject {
	private class Probably {
		var value: la_object_t = la_splat_from_float(0, Config.ATTR)
		var mean: la_object_t = la_splat_from_float(0, Config.ATTR)
		var deviation: la_object_t = la_splat_from_float(0, Config.ATTR)
		var variance: la_object_t = la_splat_from_float(0, Config.ATTR)
		var logvariance: la_object_t = la_splat_from_float(0, Config.ATTR)
	}
	private var weight: Probably = Probably()
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
		
		weight.mean = la_matrix_from_float_buffer(UnsafePointer<Float>(mean.bytes), output.width, input.width, input.width, Config.HINT, Config.ATTR)
		weight.logvariance = la_matrix_from_float_buffer(UnsafePointer<Float>(logvariance.bytes), output.width, input.width, input.width, Config.HINT, Config.ATTR)
		
		refresh()
	}
	internal func commit() {
		
		if let mean: NSMutableData = NSMutableData(length: sizeof(Float)*Int(output.width*input.width)), logvariance: NSMutableData = NSMutableData(length: sizeof(Float)*Int(output.width*input.width)) {
			
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(mean.mutableBytes), input.width, weight.mean)
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(logvariance.mutableBytes), input.width, weight.logvariance)
			
			weight.mean = la_matrix_from_float_buffer(UnsafeMutablePointer<Float>(mean.mutableBytes), output.width, input.width, input.width, Config.HINT, Config.ATTR)
			weight.logvariance = la_matrix_from_float_buffer(UnsafeMutablePointer<Float>(logvariance.mutableBytes), output.width, input.width, input.width, Config.HINT, Config.ATTR)
			
			//managedObjectContext?.performBlockAndWait {
				self.mean = mean
				self.logvariance = logvariance
			//}
		}
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
		weight.logvariance = weight.logvariance - eps * 0.5 * weight.variance * la_outer_product(variance, state * state)
		
		commit()
		
		return delta
	}
}
