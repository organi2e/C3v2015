//
//  Feedback.swift
//  C³
//
//  Created by Kota Nakano on 8/1/16.
//
//
internal class Feedback: Arcane {
	private var grad: (μ: [Float], σ: [Float]) = (
		μ: Array<Float>(),
		σ: Array<Float>()
	)
}
extension Feedback {
	@NSManaged private var cell: Cell
	internal override func setup() {
		super.setup()
		if cell.isRecurrent {
			let count: Int = cell.width
			grad.μ = Array<Float>(count: count*count*count, repeatedValue: 0)
			grad.σ = Array<Float>(count: count*count*count, repeatedValue: 0)
		}
	}
}
extension Context {
	internal func newFeedback(cell: Cell) throws -> Feedback? {
		guard let feedback: Feedback = new() else {
			throw Context.Error.CoreData.InsertionFails(entity: Feedback.self)
		}
		feedback.cell = cell
		feedback.resize(rows: cell.width, cols: cell.width)
		return feedback
	}
}
