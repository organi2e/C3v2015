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
	private var weight = (
		value: la_splat_from_float(0, Config.ATTR),
		mean: la_splat_from_float(0, Config.ATTR),
		deviation: la_splat_from_float(0, Config.ATTR),
		variance: la_splat_from_float(0, Config.ATTR),
		logvariance: la_splat_from_float(0, Config.ATTR)
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
		
		setPrimitiveValue(NSData(data: mean), forKey: "mean")
		setPrimitiveValue(NSData(data: logvariance), forKey: "logvariance")
		
		weight.mean = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(mean.bytes), output.width, input.width, input.width, Config.HINT, nil, Config.ATTR)
		weight.logvariance = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(logvariance.bytes), output.width, input.width, input.width, Config.HINT, nil, Config.ATTR)
		
		assert(weight.mean.status==LA_SUCCESS)
		assert(weight.logvariance.status==LA_SUCCESS)
		
		refresh()
		forget()
	}
	internal func commit() {
		
		managedObjectContext?.performBlockAndWait {
			self.willChangeValueForKey("mean")
			self.willChangeValueForKey("logvariance")
		}

		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(mean.bytes), input.width, weight.mean)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(logvariance.bytes), input.width, weight.logvariance)

		managedObjectContext?.performBlockAndWait {
			self.didChangeValueForKey("mean")
			self.didChangeValueForKey("logvariance")
		}
		
		weight.mean = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(mean.bytes), output.width, input.width, input.width, Config.HINT, nil, Config.ATTR)
		weight.logvariance = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(logvariance.bytes), output.width, input.width, input.width, Config.HINT, nil, Config.ATTR)
		
		assert(weight.mean.status==LA_SUCCESS)
		assert(weight.logvariance.status==LA_SUCCESS)
		
	}
	private func refresh() {
		
		weight.deviation = exp(0.5*weight.logvariance)
		weight.variance = weight.deviation * weight.deviation
		weight.value = weight.mean + weight.deviation * normal(rows: output.width, cols: input.width)
		
		assert(weight.deviation.status==LA_SUCCESS && weight.deviation.rows == output.width && weight.deviation.cols == input.width)
		assert(weight.variance.status==LA_SUCCESS && weight.variance.rows == output.width && weight.variance.cols == input.width)
		assert(weight.value.status==LA_SUCCESS && weight.value.rows == output.width && weight.value.cols == input.width)
		
	}
	private func forget() {
	
	}
	internal func iClear(let visit: Set<Cell>) {
		refresh()
		input.iClear(visit)
	}
	internal func oClear(let visit: Set<Cell>) {
		forget()
		output.oClear(visit)
	}
	internal func collect(let visit visit: Set<Cell>) -> (la_object_t, la_object_t, la_object_t) {
		let state: la_object_t = input.collect(visit: visit)
		let value: la_object_t = la_matrix_product(weight.value, state)
		let mean: la_object_t = la_matrix_product(weight.mean, state)
		let variance: la_object_t = la_matrix_product(weight.variance, state * state)
		
		assert(state.status==LA_SUCCESS && state.width == input.width)
		assert(value.status==LA_SUCCESS)
		assert(mean.status==LA_SUCCESS)
		assert(variance.status==LA_SUCCESS)
		
		return (value, mean, variance)
	}
	internal func correct(let eps eps: Float, let visit: Set<Cell>) -> la_object_t {
		let(mean, variance) = output.correct(eps: eps, visit: visit)
		
		assert(mean.status==LA_SUCCESS && mean.rows==output.width)
		assert(variance.status==LA_SUCCESS && variance.rows==output.width)
		
		let state: la_object_t = input.collect(visit: [])
		let delta: la_object_t = la_matrix_product(la_transpose(weight.value), mean)
		
		assert(state.status==LA_SUCCESS && state.rows==input.width)
		assert(delta.status==LA_SUCCESS && delta.rows==input.width)
		
		weight.mean = weight.mean + eps * la_outer_product(mean, state)
		weight.logvariance = weight.logvariance - ( 0.5 * eps ) * weight.variance * la_outer_product(variance, state * state)
		
		assert(weight.mean.status==LA_SUCCESS)
		assert(weight.logvariance.status==LA_SUCCESS)
		
		commit()
		
		return delta
	}
}
extension Edge {
	internal func isChained(let cell: Cell)->Bool {
		return cell === input
	}
	internal func iTrace(let task:(Cell)->()) {
		input.iTrace(task)
	}
	internal func oTrace(let task:(Cell)->()) {
		output.oTrace(task)
	}
}