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
	
}
extension Edge {
	@NSManaged internal var input: Cell
	@NSManaged internal var output: Cell
}
extension Edge {
	override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
}
extension Edge {
	internal func collect(let visit: Set<Cell>) -> (la_object_t, la_object_t, la_object_t) {
		let state: la_object_t = input.collect(visit: visit)
		return(la_matrix_product(value, state), la_matrix_product(mean, state), la_matrix_product(variance, state*state))
	}
	
	internal func correct(let eps eps: Float, let visit: Set<Cell>) -> la_object_t {
		
		let state: la_object_t = input.collect(visit: [])
		assert(state.status==LA_SUCCESS && state.rows==input.width)
		
		let delta: (la_object_t, la_object_t) = output.correct(eps: eps, visit: visit)
		assert(delta.0.status==LA_SUCCESS && delta.0.rows==output.width)
		assert(delta.1.status==LA_SUCCESS && delta.1.rows==output.width)
		
		mean = mean + eps * la_outer_product(delta.0, state)
		assert(mean.status==LA_SUCCESS)
		
		logvariance = logvariance - ( 0.5 * eps ) * variance * la_outer_product(delta.1, state * state)
		assert(logvariance.status==LA_SUCCESS)
		
		commit()
		
		return la_matrix_product(la_transpose(value), delta.0)
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
