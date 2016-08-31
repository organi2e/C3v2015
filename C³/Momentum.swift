//
//  Momentum.swift
//  C³
//
//  Created by Kota Nakano on 8/31/16.
//
//

import Foundation
internal class Momentum {
	private let α: Float
	private let w: [Float]
	private var W: LaObjet {
		return LaMatrice(w, rows: w.count, cols: 1, deallocator: nil)
	}
	init(dim: Int, α v: Float) {
		α = v
		w = [Float](count: dim, repeatedValue: 0)
	}
}
extension Momentum: GradientOptimizer {
	func optimize(Δx Δw: LaObjet, x: LaObjet) -> LaObjet {
		(α * W + Δw).getBytes(w)
		return W
	}
}