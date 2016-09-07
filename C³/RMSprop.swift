//
//  RMSProp.swift
//  C³
//
//  Created by Kota Nakano on 8/31/16.
//
//
import Accelerate
internal class RMSprop {
	private static let γ: Float = 0.9
	private static let η: Float = 0.5
	private let γ: Float
	private let η: Float
	private let w: [Float]
	private let r: [Float]
	private var W: LaObjet {
		return LaMatrice(w, rows: w.count, cols: 1, deallocator: nil)
	}
	private var R: LaObjet {
		return LaMatrice(r, rows: r.count, cols: 1, deallocator: nil)
	}
	init(dim: Int, η n: Float = η, γ v: Float = γ) {
		γ = v
		η = n
		w = [Float](count: dim, repeatedValue: 0)
		r = [Float](count: dim, repeatedValue: 0)
	}
	static func factory(η η: Float = η, γ: Float = γ) -> Int -> GradientOptimizer {
		return {
			RMSprop(dim: $0, η: η, γ: γ)
		}
	}
}
extension RMSprop: GradientOptimizer {
	func optimize(Δx Δx: LaObjet, x: LaObjet) -> LaObjet {
		(γ*W+(1-γ)*Δx*Δx).getBytes(w)
		vvrsqrtf(UnsafeMutablePointer<Float>(r), w, [Int32(min(r.count, w.count))])
		return η * Δx * R
	}
	func reset() {
		vDSP_vclr(UnsafeMutablePointer<Float>(w), 1, vDSP_Length(w.count))
		vDSP_vclr(UnsafeMutablePointer<Float>(r), 1, vDSP_Length(r.count))
	}
}