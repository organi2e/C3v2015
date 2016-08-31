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
			update = self.dynamicType.SR1
		case .Broyden:
			update = self.dynamicType.Boyden
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
		return LaMatrice(h, rows: prevy.count, cols: prevx.count)
	}
	private static func DFP(H: LaObjet, Δy: LaObjet, Δx: LaObjet) -> LaObjet {
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
	private static func Boyden(H: LaObjet, Δy: LaObjet, Δx: LaObjet) -> LaObjet {
		return H
	}
	private static func SR1(H: LaObjet, Δy: LaObjet, Δx: LaObjet) -> LaObjet {
		let δ: LaObjet = Δx - matrix_product(H, Δy)
		let Ρ: LaObjet = inner_product(δ, Δy)
		if let ρ: Float = Ρ.array.first where 0 < abs(ρ) {
			return H + (1/ρ) * outer_product(δ, δ)
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

internal class BFGS {
	private let I: LaObjet
	private let b: [Float]
	private let prevg: [Float]
	private let prevx: [Float]
	private let Θ: Float
	private var B: LaObjet {
		return LaMatrice(b, rows: I.rows, cols: I.cols, deallocator: nil)
	}
	private var prevX: LaObjet {
		return LaMatrice(prevx, rows: prevx.count, cols: 1, deallocator: nil)
	}
	private var prevG: LaObjet {
		return LaMatrice(prevg, rows: prevg.count, cols: 1, deallocator: nil)
	}
	init(dim: Int, threshold: Float = 1e-24) {
		prevx = [Float](count: dim, repeatedValue: 0)
		prevg = [Float](count: dim, repeatedValue: 0)
		b = [Float](count: dim*dim, repeatedValue: 0)
		I = LaIdentité(dim)
		I.getBytes(b)
		Θ = threshold
	}
	func update(g g: LaObjet, x: LaObjet, threshold: Float? = nil) -> LaObjet {
		defer {
			x.getBytes(prevx)
			g.getBytes(prevg)
		}
		let s: LaObjet = x - prevX
		let y: LaObjet = g - prevG
		let ρ: LaObjet = inner_product(y, s)
		if let ρ: Float = ρ.array.first where !isinf(ρ) && !isnan(ρ) && ( threshold ?? Θ ) < abs(ρ) {
			let r: Float = 1 / ρ
			if !isinf(r) && !isnan(r) {
				let J: LaObjet = outer_product(s, y)
				let G: LaObjet = I - r * J
				(matrix_product(matrix_product(G, B), G.T) + r * outer_product(s, s)).getBytes(b)
			}
		}
		return matrix_product(B, g)
	}
}