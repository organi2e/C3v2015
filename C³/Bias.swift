//
//  Bias.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Accelerate
internal class Bias: Gauss {
	var gradient: la_object_t = la_splat_from_float(0, Config.ATTR)
}
extension Bias {
	@NSManaged internal var cell: Cell
}
extension Bias {
	override func setup() {
		super.setup()
		gradient = la_matrix_from_splat(la_splat_from_float(0, Config.ATTR), rows, rows * cols)
		assert(gradient.status==LA_SUCCESS&&gradient.rows==rows&&gradient.cols==rows*cols)
	}
}
extension Bias {
	func collect() -> (la_object_t, la_object_t, la_object_t) {
		return(value, mean, variance)
	}
	func correct(let eps eps: Float, let mean deltamean: la_object_t, let variance deltavariance: la_object_t) {
		mean = mean + eps * la_matrix_product(la_transpose(deltamean), gradient).reshape(rows: rows, cols: cols)
		assert(mean.status==LA_SUCCESS&&mean.rows==rows&&mean.cols==cols)
		
		logvariance = logvariance - ( 0.5 * eps ) * variance * la_matrix_product(la_transpose(deltavariance), gradient).reshape(rows: rows, cols: cols)
		assert(logvariance.status==LA_SUCCESS&&logvariance.rows==rows&&logvariance.cols==cols)
	}
	override func commit() {
		super.commit()
		gradient = gradient.dup
		assert(gradient.status==LA_SUCCESS&&gradient.rows==rows&&gradient.cols==rows*cols)
	}
}
extension Context {
	internal func newBias(let width width: UInt) throws -> Bias {
		guard let bias: Bias = new() else {
			throw Error.EntityError.InsertionFails(entity: className)
		}
		bias.resize(rows: width, cols: 1)
		return bias
	}
}