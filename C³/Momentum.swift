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
	private static let η: Float = 0.5
	private let α: Float
	private let η: Float
	private let w: [Float]
	private var W: LaObjet {
		return LaMatrice(w, rows: w.count, cols: 1, deallocator: nil)
	}
	init(dim: Int, α v: Float = α, η n: Float = η) {
		α = v
		η = n
		w = [Float](count: dim, repeatedValue: 0)
	}
	static func factory(α α: Float = α, η: Float = η) -> Int -> GradientOptimizer {
		return {
			Momentum(dim: $0, α: α, η: η)
		}
	}
}
extension Momentum: GradientOptimizer {
	public func optimize(Δx Δw: LaObjet, x: LaObjet) -> LaObjet {
		(α * W + Δw).getBytes(w)
		return η * W
	}
	public func reset() {
		vDSP_vclr(UnsafeMutablePointer<Float>(w), 1, vDSP_Length(w.count))
	}
}