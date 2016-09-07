//
//  Momentum.swift
//  C³
//
//  Created by Kota Nakano on 8/31/16.
//
//
import Accelerate
public class Momentum {
	private static let α: Float = 0.5
	private static let r: Float = 0.95
	private static let η: Float = 0.5
	private let α: Float
	private let r: Float
	private let η: Float
	private let w: [Float]
	private var W: LaObjet {
		return LaMatrice(w, rows: w.count, cols: 1, deallocator: nil)
	}
	init(dim: Int, α v: Float = α, r λ: Float, η n: Float = η) {
		α = v
		r = λ
		η = n
		w = [Float](count: dim, repeatedValue: 0)
	}
	static func factory(α α: Float = α, r: Float = r, η: Float = η) -> Int -> GradientOptimizer {
		return {
			Momentum(dim: $0, α: α, r: r, η: η)
		}
	}
}
extension Momentum: GradientOptimizer {
	public func optimize(Δx Δw: LaObjet, x: LaObjet) -> LaObjet {
		(r * W + α * Δw).getBytes(w)
		return η * W
	}
	public func reset() {
		vDSP_vclr(UnsafeMutablePointer<Float>(w), 1, vDSP_Length(w.count))
	}
}