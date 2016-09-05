//
//  Refraction.swift
//  C³
//
//  Created by Kota Nakano on 9/6/16.
//
//
import Accelerate
public class Refraction {
	private static let r: Float = 0.5
	private static let η: Float = 0.5
	private let r: Float
	private let η: Float
	private let w: [Float]
	private var W: LaObjet {
		return LaMatrice(w, rows: w.count, cols: 1, deallocator: nil)
	}
	init(dim: Int, r v: Float = r, η n: Float = η) {
		r = v
		η = n
		w = [Float](count: dim, repeatedValue: 0)
	}
	static func factory(r r: Float = r, η: Float = η) -> Int -> GradientOptimizer {
		return {
			Refraction(dim: $0, r: r, η: η)
		}
	}
}
extension Refraction: GradientOptimizer {
	public func optimize(Δx Δw: LaObjet, x: LaObjet) -> LaObjet {
		let LN: LaObjet = inner_product(W, Δw)
		(r * W + Δw).getBytes(w)
		return η * W
	}
	public func reset() {
		vDSP_vclr(UnsafeMutablePointer<Float>(w), 1, vDSP_Length(w.count))
	}
}