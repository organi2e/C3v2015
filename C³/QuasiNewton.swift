//
//  BFGS.swift
//  C³
//
//  Created by Kota Nakano on 8/30/16.
//
//
import Foundation
internal class QuasiNewton {
	internal enum Type {
		case DavidonFletcherPowell
		case DFP
		case BroydenFletcherGoldfarbShanno
		case BFGS
		case SymmetricRank1
		case SR1
		case Broyden
	}
	private let h: [Float]
	private let prevy: [Float]
	private let prevx: [Float]
	private let update: (LaObjet,LaObjet,LaObjet)->LaObjet
	init(dim: Int, type: Type) {
		prevx = [Float](count: dim, repeatedValue: 0)
		prevy = [Float](count: dim, repeatedValue: 0)
		h = [Float](count: dim*dim, repeatedValue: 0)
		LaIdentité(dim).getBytes(h)
		switch type {
		case .DavidonFletcherPowell, .DFP:
			update = self.dynamicType.DFP
		case .BroydenFletcherGoldfarbShanno, .BFGS:
			update = self.dynamicType.BFGS
		case .Broyden:
			update = self.dynamicType.Broyden
		case .SymmetricRank1, .SR1:
			update = self.dynamicType.SR1
		}
	}
	private var prevX: LaObjet {
		return LaMatrice(prevx, rows: prevx.count, cols: 1, deallocator: nil)
	}
	private var prevY: LaObjet {
		return LaMatrice(prevy, rows: prevy.count, cols: 1, deallocator: nil)
	}
	private var H: LaObjet {
		return LaMatrice(h, rows: prevy.count, cols: prevx.count, deallocator: nil)
	}
	private static func DFP(H: LaObjet, Δy: LaObjet, Δx: LaObjet) -> LaObjet {
		let XX: LaObjet = outer_product(Δx, Δx.T)
		let XY: LaObjet = inner_product(Δx.T, Δy)
		let HYYH: LaObjet = outer_product(matrix_product(H, Δy), matrix_product(Δy.T, H))
		let YHY: LaObjet = inner_product(Δy.T, matrix_product(H, Δy))
		if let xy: Float = XY.array.first, yhy: Float = YHY.array.first where 0 < abs(xy) && 0 < abs(yhy) {
			let α: Float = 1 / xy
			let β: Float = 1 / yhy
			return H + ( isinf(α) || isnan(α) ? 0 : α ) * XX - ( isinf(β) || isnan(β) ? 0 : β ) * HYYH
		}
		return H
	}
	private static func BFGS(H: LaObjet, Δy: LaObjet, Δx: LaObjet) -> LaObjet {
		let Ρ: LaObjet = inner_product(Δy, Δx)
		if let ρ: Float = Ρ.array.first where 0 < abs(ρ) {
			let r: Float = 1 / ρ
			let M: LaObjet = LaIdentité(max(H.rows, H.cols)) - r * outer_product(Δx, Δy)
			return matrix_product(matrix_product(M, H), M.T) + r * outer_product(Δx, Δx)
		}
		return H
	}
	private static func Broyden(H: LaObjet, Δy: LaObjet, Δx: LaObjet) -> LaObjet {
		let HY: LaObjet = matrix_product(H, Δy)
		let Ρ: LaObjet = inner_product(Δx.T, HY)
		if let ρ: Float = Ρ.array.first where 0 < abs(ρ) {
			let r: Float = 1 / ρ
			return H + ( isinf(r) || isnan(r) ? 0 : r ) * outer_product(Δx-HY, matrix_product(Δx.T, H))
		}
		return H
	}
	private static func SR1(H: LaObjet, Δy: LaObjet, Δx: LaObjet) -> LaObjet {
		let δ: LaObjet = Δx - matrix_product(H, Δy)
		let Ρ: LaObjet = inner_product(δ, Δy)
		if let ρ: Float = Ρ.array.first where 0 < abs(ρ) {
			let r: Float = 1 / ρ
			return H + ( isinf(r) || isnan(r) ? 0 : r ) * outer_product(δ, δ)
		}
		return H
	}
}
extension QuasiNewton: GradientOptimizer {
	func optimize(Δx y: LaObjet, x: LaObjet) -> LaObjet {
		defer {
			x.getBytes(prevx)
			y.getBytes(prevy)
		}
		let Δx: LaObjet = prevX - x
		let Δy: LaObjet = prevY - y
		update(H, Δy, Δx).getBytes(h)
		return matrix_product(H, y)
	}
}