//
//  Adam.swift
//  C³
//
//  Created by Kota Nakano on 8/31/16.
//
//
import Accelerate
internal class Adam {
	let α: Float
	let β1: Float
	let β2: Float
	let ε: Float
	let m: [Float]
	let v: [Float]
	let eμ: [Float]
	let eσ: [Float]
	let w: [Float]
	var k: Int
	var M: LaObjet {
		return LaMatrice(m, rows: m.count, cols: 1)
	}
	var μ: LaObjet {
		return LaMatrice(eμ, rows: eμ.count, cols: 1)
	}
	var V: LaObjet {
		return LaMatrice(v, rows: v.count, cols: 1)
	}
	var σ: LaObjet {
		return LaMatrice(eσ, rows: eσ.count, cols: 1)
	}
	var W: LaObjet {
		return LaMatrice(w, rows: w.count, cols: 1)
	}
	init(dim: Int) {
		k = 0
		α = 1e-3
		β1 = 0.9
		β2 = 0.999
		ε = 1e-8
		w = [Float](count: dim, repeatedValue: 0)
		m = [Float](count: dim, repeatedValue: 0)
		v = [Float](count: dim, repeatedValue: 0)
		eμ = [Float](count: dim, repeatedValue: 0)
		eσ = [Float](count: dim, repeatedValue: 0)
	}
	func reset() {
		k = 0
		vDSP_vclr(UnsafeMutablePointer<Float>(m), 1, vDSP_Length(m.count))
		vDSP_vclr(UnsafeMutablePointer<Float>(v), 1, vDSP_Length(v.count))
	}
}
extension Adam: GradientOptimizer {
	func optimize(Δx g: LaObjet, x: LaObjet) -> LaObjet {
		k = k + 1
		(β1*M+(1-β1)*g).getBytes(m)
		(β2*V+(1-β2)*(g*g)).getBytes(v)
		((1/(1-pow(β1, Float(k)))*M)).getBytes(eμ)
		((1/(1-pow(β2, Float(k)))*V)).getBytes(eσ)
		vvrsqrtf(UnsafeMutablePointer<Float>(eσ), eσ, [Int32(eσ.count)])
		return μ * σ
	}
}