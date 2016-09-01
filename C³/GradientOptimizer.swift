//
//  GradientOptimizer.swift
//  C³
//
//  Created by Kota Nakano on 8/31/16.
//
//
internal protocol GradientOptimizer {
	func optimize(Δx Δx: LaObjet, x: LaObjet) -> LaObjet
	func reset()
}
public class SGD {
	private static let η: Float = 0.5
	private let η: Float
	init(η n: Float = η) {
		η = n
	}
	static func factory(η η: Float = η) -> Int -> GradientOptimizer {
		return {(_) -> GradientOptimizer in
			SGD(η: η)
		}
	}
}
extension SGD: GradientOptimizer {
	func optimize(Δx Δx: LaObjet, x: LaObjet) -> LaObjet {
		return η * Δx
	}
	func reset() {
		
	}
}