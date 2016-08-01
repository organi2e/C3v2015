//
//  Feedback.swift
//  C³
//
//  Created by Kota Nakano on 8/1/16.
//
//
import CoreData
internal class Feedback: Gauss {
	
}
extension Feedback {
	@NSManaged private var cell: Cell
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