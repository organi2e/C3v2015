//
//  Circular.swift
//  C³
//
//  Created by Kota Nakano on 8/1/16.
//
//

class Circular: Arcane {
	private var grad: (μ: [Float], σ: [Float]) = (
		μ: Array<Float>(),
		σ: Array<Float>()
	)
}
extension Circular {
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
	@nonobjc internal func newCircular(let cell cell: Cell) throws -> Circular {
		guard let circular: Circular = new() else {
			throw Context.Error.CoreData.InsertionFails(entity: Circular.self)
		}
		circular.cell = cell
		circular.resize(rows: cell.width, cols: cell.width)
		return circular
	}
}
