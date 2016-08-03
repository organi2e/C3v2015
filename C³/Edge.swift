//
//  Edge.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import Accelerate
import CoreData

internal class Edge: Gauss {
	private var gradient = (
		input: la_splat_from_float(0, Config.ATTR),
		mean: la_splat_from_float(0, Config.ATTR),
		variance: la_splat_from_float(0, Config.ATTR)
	)
}
extension Edge {
	@NSManaged internal var input: Cell
	@NSManaged internal var output: Cell
}
extension Edge {
	override func setup() {
		super.setup()
		
		gradient.input = la_matrix_from_splat(la_splat_from_float(0, Config.ATTR), rows, cols)
		assert(gradient.input.status==LA_SUCCESS && gradient.input.rows==rows && gradient.input.cols==cols)
		
		gradient.mean = la_matrix_from_splat(la_splat_from_float(0, Config.ATTR), rows, rows * cols)
		assert(gradient.mean.status==LA_SUCCESS && gradient.mean.rows==rows && gradient.mean.cols==rows*cols)
		
		gradient.variance = la_matrix_from_splat(la_splat_from_float(0, Config.ATTR), rows, rows * cols)
		assert(gradient.variance.status==LA_SUCCESS && gradient.variance.rows==rows && gradient.variance.cols==rows*cols)
		
		
	}
}
extension Edge {
	func collect(let visit: Set<Cell>) -> (la_object_t, la_object_t, la_object_t) {
		let state: la_object_t = input.collect(visit: visit)
		return(la_matrix_product(value, state), la_matrix_product(mean, state), la_matrix_product(variance, state*state))
	}
	func correct(let eps eps: Float, let visit: Set<Cell>) -> (la_object_t) {
		
		let(deltamean, deltavariance, lambda, dydv, feedback) = output.correct(eps: eps, visit: visit)
		let state: la_object_t = input.state.value
		
		var gradientinput: la_object_t = value
		var gradientmean: la_object_t = la_transpose(state).toIdentity(rows)
		var gradientvariance: la_object_t = la_transpose(state*state).toIdentity(rows)
		
		if let lambda: la_object_t = lambda {
			gradientinput = gradientinput + la_matrix_product(la_diagonal_matrix_from_vector(lambda, 0), gradient.input)
			gradientmean = gradientmean + la_matrix_product(la_diagonal_matrix_from_vector(lambda, 0), gradient.mean)
			gradientvariance = gradientvariance + la_matrix_product(la_diagonal_matrix_from_vector(lambda*lambda, 0), gradient.variance)
		}
		if let feedback: la_object_t = feedback {
			gradientinput = gradientinput + la_matrix_product(feedback, la_matrix_product(la_diagonal_matrix_from_vector(dydv, 0), gradient.input))
			gradientmean = gradientmean + la_matrix_product(feedback, la_matrix_product(la_diagonal_matrix_from_vector(dydv, 0), gradient.mean))
			gradientvariance = gradientvariance + la_matrix_product(feedback, la_matrix_product(la_diagonal_matrix_from_vector(dydv, 0), gradient.variance))
		}
		
		gradient.input = gradientinput.dup
		assert(gradient.input.status==LA_SUCCESS&&gradient.input.rows==rows&&gradient.input.cols==cols)
		
		gradient.mean = gradientmean.dup
		assert(gradient.mean.status==LA_SUCCESS&&gradient.mean.rows==rows&&gradient.mean.cols==rows*cols)
		
		gradient.variance = gradientvariance.dup
		assert(gradient.variance.status==LA_SUCCESS&&gradient.variance.rows==rows&&gradient.variance.cols==rows*cols)
		
		mean = mean + eps * la_matrix_product(la_transpose(deltamean), gradient.mean).reshape(rows: rows, cols: cols)
		assert(mean.status==LA_SUCCESS&&mean.rows==rows&&mean.cols==cols)
		
		logvariance = logvariance - ( 0.5 * eps ) * variance * la_matrix_product(la_transpose(deltavariance), gradient.variance).reshape(rows: rows, cols: cols)
		assert(logvariance.status==LA_SUCCESS&&logvariance.rows==rows&&logvariance.cols==cols)
		
		commit()
		
		return la_matrix_product(la_transpose(gradient.input), deltamean)
	}
}
extension Context {
	internal func newEdge(let output output: Cell, let input: Cell) throws -> Edge {
		guard let edge: Edge = new() else {
			throw Error.EntityError.InsertionFails(entity: className)
		}
		edge.resize(rows: output.width, cols: input.width)
		edge.output = output
		edge.input = input
		return edge
	}
}
