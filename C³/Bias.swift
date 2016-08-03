//
//  Bias.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Accelerate
internal class Bias: Gauss {
	var gradient = (
		mean: la_splat_from_float(0, Config.ATTR),
		variance: la_splat_from_float(0, Config.ATTR)
	)
}
extension Bias {
	@NSManaged internal var cell: Cell
}
extension Bias {
	override func setup() {
		super.setup()
		
		gradient.mean = la_matrix_from_splat(la_splat_from_float(0, Config.ATTR), rows, rows * cols)
		assert(gradient.mean.status==LA_SUCCESS&&gradient.mean.rows==rows&&gradient.mean.cols==rows*cols)
		
		gradient.variance = la_matrix_from_splat(la_splat_from_float(0, Config.ATTR), rows, rows * cols)
		assert(gradient.variance.status==LA_SUCCESS&&gradient.variance.rows==rows&&gradient.variance.cols==rows*cols)
	}
}
extension Bias {
	func collect() -> (la_object_t, la_object_t, la_object_t) {
		return(value, mean, variance)
	}
	func correct(let eps eps: Float, let mean deltamean: la_object_t, let variance deltavariance: la_object_t, let lambda: la_object_t? = nil, let dydv: la_object_t? = nil, let feedback: la_object_t? = nil ) {
		
		var gradientmean: la_object_t = la_identity_matrix(rows, la_scalar_type_t(LA_SCALAR_TYPE_FLOAT), Config.ATTR)
		var gradientvariance: la_object_t = la_identity_matrix(rows, la_scalar_type_t(LA_SCALAR_TYPE_FLOAT), Config.ATTR)
		
		if let lambda: la_object_t = lambda {
			gradientmean = gradientmean + la_matrix_product(la_diagonal_matrix_from_vector(lambda, 0), gradient.mean)
			gradientvariance = gradientvariance + la_matrix_product(la_diagonal_matrix_from_vector(lambda*lambda, 0), gradient.variance)
		}
		
		if let dydv: la_object_t = dydv, feedback: la_object_t = feedback {
			gradientmean = gradientmean + la_matrix_product(la_matrix_product(la_diagonal_matrix_from_vector(dydv, 0), feedback), gradient.mean)
			gradientvariance = gradientvariance + la_matrix_product(la_matrix_product(la_diagonal_matrix_from_vector(dydv, 0), feedback), gradient.variance)
		}
		
		gradient.mean = gradientmean.dup
		assert(gradient.mean.status==LA_SUCCESS&&gradient.mean.rows==rows&&gradient.mean.cols==rows*cols)
		
		gradient.variance = gradientvariance.dup
		assert(gradient.variance.status==LA_SUCCESS&&gradient.variance.rows==rows&&gradient.variance.cols==rows*cols)
		
		mean = mean + eps * la_matrix_product(la_transpose(deltamean), gradient.mean).reshape(rows: rows, cols: cols)
		assert(mean.status==LA_SUCCESS&&mean.rows==rows&&mean.cols==cols)
		
		logvariance = logvariance - ( 0.5 * eps ) * variance * la_matrix_product(la_transpose(deltavariance), gradient.variance).reshape(rows: rows, cols: cols)
		assert(logvariance.status==LA_SUCCESS&&logvariance.rows==rows&&logvariance.cols==cols)

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