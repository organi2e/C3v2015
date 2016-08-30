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
		return matrix(b, rows: I.rows, cols: I.cols, deallocator: nil)
	}
	private var prevX: LaObjet {
		return matrix(prevx, rows: prevx.count, cols: 1, deallocator: nil)
	}
	private var prevG: LaObjet {
		return matrix(prevg, rows: prevg.count, cols: 1, deallocator: nil)
	}
	init(dim: Int, threshold: Float = 1e-24) {
		prevx = [Float](count: dim, repeatedValue: 0)
		prevg = [Float](count: dim, repeatedValue: 0)
		b = [Float](count: dim*dim, repeatedValue: 0)
		I = matrix_eye(dim)
		I.getBytes(b)
		Θ = threshold
	}
	func update(g gc: [Float], x xc: [Float], threshold: Float? = nil) -> LaObjet {
		let x: LaObjet = matrix(xc, rows: xc.count, cols: 1)
		let g: LaObjet = matrix(gc, rows: gc.count, cols: 1)
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