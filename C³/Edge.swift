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
	var gradient: la_object_t = la_splat_from_float(0, Config.ATTR)
}
extension Edge {
	@NSManaged internal var input: Cell
	@NSManaged internal var output: Cell
}
extension Edge {
	override func setup() {
		super.setup()
		gradient = la_matrix_from_splat(la_splat_from_float(0, Config.ATTR), rows, rows * cols)
		assert(gradient.status==LA_SUCCESS&&gradient.rows==rows&&gradient.cols==rows*cols)
	}
}
extension Edge {
	func collect(let visit: Set<Cell>) -> (la_object_t, la_object_t, la_object_t) {
		let state: la_object_t = input.collect(visit: visit)
		return(la_matrix_product(value, state), la_matrix_product(mean, state), la_matrix_product(variance, state*state))
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
