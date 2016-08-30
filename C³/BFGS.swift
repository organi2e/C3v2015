//
//  BFGS.swift
//  C³
//
//  Created by Kota Nakano on 8/30/16.
//
//
import Foundation
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