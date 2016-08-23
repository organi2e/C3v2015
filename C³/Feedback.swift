//
//  Feedback.swift
//  C³
//
//  Created by Kota Nakano on 8/1/16.
//
//
import Accelerate
import CoreData
internal class Feedback: Gauss {
	/*
	var gradient = (
		mean: la_splat_from_float(0, Config.ATTR),
		variance: la_splat_from_float(0, Config.ATTR)
	)
	*/
}
extension Feedback {
	@NSManaged private var cell: Cell
}
extension Feedback {
}
extension Feedback {
	func collect() -> (MTLBuffer, MTLBuffer, MTLBuffer) {
		//let state: la_object_t = cell.state.past.value
		return(
			χ, χ, χ
		)
	}
	func correct(let eps eps: Float, let mean deltamean: la_object_t, let variance deltavariance: la_object_t, let state: la_object_t, let dydv: la_object_t, let lambda: la_object_t? = nil) {
		/*
		var gradientmean: la_object_t = la_transpose(state).toIdentity(rows)
		var gradientvariance: la_object_t = la_transpose(state*state).toIdentity(rows)
		
		if let lambda: la_object_t = lambda {
			gradientmean = gradientmean + la_matrix_product(la_diagonal_matrix_from_vector(lambda, 0), gradient.mean)
			gradientvariance = gradientvariance + la_matrix_product(la_diagonal_matrix_from_vector(lambda*lambda, 0), gradient.variance)
		}
		
		gradientmean = gradientmean + la_matrix_product(value, la_matrix_product(la_diagonal_matrix_from_vector(dydv, 0), gradient.mean))
		gradientvariance = gradientvariance + la_matrix_product(value, la_matrix_product(la_diagonal_matrix_from_vector(dydv, 0), gradient.variance))

		gradient.mean = gradientmean.dup
		assert(gradient.mean.status==LA_SUCCESS&&gradient.mean.rows==rows&&gradient.mean.cols==rows*cols)
		
		gradient.variance = gradientvariance.dup
		assert(gradient.variance.status==LA_SUCCESS&&gradient.variance.rows==rows&&gradient.variance.cols==rows*cols)
		
		mean = mean + eps * la_matrix_product(la_transpose(deltamean), gradient.mean).reshape(rows: rows, cols: cols)
		assert(mean.status==LA_SUCCESS&&mean.rows==rows&&mean.cols==cols)
		
		logvariance = logvariance - ( 0.5 * eps ) * variance * la_matrix_product(la_transpose(deltavariance), gradient.variance).reshape(rows: rows, cols: cols)
		assert(logvariance.status==LA_SUCCESS&&logvariance.rows==rows&&logvariance.cols==cols)
		*/
	}
}
extension Context {
	internal func newFeedback(let width width: Int) throws -> Feedback {
		guard let feedback: Feedback = new() else {
			throw Error.CoreData.InsertionFails(entity: Feedback.className())
		}
		feedback.resize(rows: width, cols: width)
		return feedback
	}
	
}