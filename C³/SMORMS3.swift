//
//  SMORMS3.swift
//  C³
//
//  Created by Kota Nakano on 8/31/16.
//
//
import Accelerate
internal class SMORMS3 {
	private let α: Float
	private let ε: Float
	private let mem: [Float]
	private let g: [Float]
	private let g2: [Float]
	private var x: [Float]
	private var MEM: LaObjet {
		return LaMatrice(mem, rows: mem.count, cols: 1)
	}
	private var G: LaObjet {
		return LaMatrice(g, rows: g.count, cols: 1)
	}
	private var G2: LaObjet {
		return LaMatrice(g2, rows: g2.count, cols: 1)
	}
	private var X: LaObjet {
		return LaMatrice(x, rows: x.count, cols: 1)
	}
	init(dim: Int, α a: Float = 1-3, ε e: Float = 1e-24) {
		α = a
		ε = e
		mem = [Float](count: dim, repeatedValue: 1)
		g = [Float](count: dim, repeatedValue: 0)
		g2 = [Float](count: dim, repeatedValue: 0)
		x = [Float](count: dim, repeatedValue: 0)
	}
}
extension SMORMS3: GradientOptimizer {
	func optimize(Δx grad: LaObjet, x _: LaObjet) -> LaObjet {
		let r: LaObjet = 1 / ( 1 + MEM )
		((1-r) * G + r * grad).getBytes(g)
		((1-r) * G2 + r * grad * grad).getBytes(g2)
		(1+MEM*(1-G*G/(G2+ε))).getBytes(mem)
		for k in 0..<x.count {
			x[k] = (g[k]*g[k]/(g2[k]+ε))/(sqrt(g2[k])+ε)
		}
		return grad * X
	}
}