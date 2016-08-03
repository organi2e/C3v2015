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
	var gradient: la_object_t = la_splat_from_float(0, Config.ATTR)
}
extension Feedback {
	@NSManaged private var cell: Cell
}
extension Feedback {
	override func setup() {
		super.setup()
		assert(rows==cols)
		gradient = la_matrix_from_splat(la_splat_from_float(0, Config.ATTR), rows, rows * cols)
	}
}
extension Feedback {
	func collect() -> (la_object_t, la_object_t, la_object_t) {
		let state: la_object_t = cell.state.past.value
		return(
			la_matrix_product(value, state),
			la_matrix_product(mean, state),
			la_matrix_product(variance, state * state)
		)
	}
	func correct(let eps eps: Float, let mean deltamean: la_object_t, let variance deltavariance: la_object_t) {
		mean = mean + eps * la_matrix_product(la_transpose(deltamean), gradient).reshape(rows: rows, cols: cols)
		assert(mean.status==LA_SUCCESS&&mean.rows==rows&&mean.cols==cols)
		
		logvariance = logvariance - ( 0.5 * eps ) * variance * la_matrix_product(la_transpose(deltavariance), gradient).reshape(rows: rows, cols: cols)
		assert(logvariance.status==LA_SUCCESS&&logvariance.rows==rows&&logvariance.cols==cols)
	}
}
extension Context {
	internal func newFeedback(let width width: UInt) throws -> Feedback {
		guard let feedback: Feedback = new() else {
			throw Error.EntityError.InsertionFails(entity: NSStringFromClass(Feedback.self))
		}
		feedback.resize(rows: width, cols: width)
		return feedback
	}
	
}