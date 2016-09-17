//
//  Circular.swift
//  C³
//
//  Created by Kota Nakano on 8/1/16.
//
//
import CoreData
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
extension Circular {
	internal func chain(x: (μ: LaObjet, σ: LaObjet)) -> (μ: LaObjet, σ: LaObjet) {
		let ξ: GaussianDistribution.Type = GaussianDistribution.self
		let y: LaObjet = ξ.test1(cell._χ)
		let dydλ: LaObjet = cell._Δ
		let μB: LaObjet = μ
		let σB: LaObjet = ξ.test2(σ)
		
		return (
			μ: matrix_product(μ, x.μ),
			σ: matrix_product(σ, x.σ)
		)
	}
}
extension Context {
	internal func newCircular(cell: Cell) throws -> Circular {
		guard let circular: Circular = new() else {
			throw Context.Error.CoreData.InsertionFails(entity: Circular.self)
		}
		circular.cell = cell
		circular.resize(rows: cell.width, cols: cell.width)
		return circular
	}
}


