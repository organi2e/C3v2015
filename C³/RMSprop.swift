//
//  RMSProp.swift
//  C³
//
//  Created by Kota Nakano on 8/31/16.
//
//
import Accelerate
internal class RMSprop {
	private let γ: Float
	private let w: [Float]
	private let r: [Float]
	private var W: LaObjet {
		return LaMatrice(w, rows: w.count, cols: 1, deallocator: nil)
	}
	private var R: LaObjet {
		return LaMatrice(r, rows: r.count, cols: 1, deallocator: nil)
	}
	init(dim: Int, γ v: Float) {
		γ = v
		w = [Float](count: dim, repeatedValue: 0)
		r = [Float](count: dim, repeatedValue: 0)
	}
}
extension RMSprop: GradientOptimizer {
	func optimize(Δx Δx: LaObjet, x: LaObjet) -> LaObjet {
		(γ*W+Δx*Δx).getBytes(w)
		vvrsqrtf(UnsafeMutablePointer<Float>(r), w, [Int32(min(r.count, w.count))])
		return Δx * R
	}
}