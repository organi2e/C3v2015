//
//  ConjugateGradient.swift
//  C³
//
//  Created by Kota Nakano on 8/30/16.
//
//
import Foundation
internal class ConjugateGradient {
	internal enum Condition {
		case FletcherReeves
		case PolakRibière
		case HestenesStiefe
		case DaiYuan
	}
	private let condition: Condition
	private let p: [Float]
	private let g: [Float]
	private var P: LaObjet {
		return LaMatrice(p, rows: p.count, cols: 1, deallocator: nil)
	}
	private var prevG: LaObjet {
		return LaMatrice(g, rows: g.count, cols: 1, deallocator: nil)
	}
	init(dim: Int, condition c: Condition = .FletcherReeves){
		p = [Float](count: dim, repeatedValue: 0)
		g = [Float](count: dim, repeatedValue: 0)
		condition = c
	}
}
extension ConjugateGradient: GradientOptimizer {
	func optimize(Δx G: LaObjet, x: LaObjet) -> LaObjet {
		defer {
			G.getBytes(g)
		}
		let fraction: (m: LaObjet, M: LaObjet) = {(condition: Condition, P: LaObjet, prevG: LaObjet, G: LaObjet)->(LaObjet, LaObjet)in
			switch condition {
			case .FletcherReeves:
				return(
					inner_product(G, G),
					inner_product(prevG, prevG)
				)
			case .PolakRibière:
				return(
					inner_product(G, G-prevG),
					inner_product(prevG, prevG)
				)
			case .HestenesStiefe:
				return(
					inner_product(G, G-prevG),
					inner_product(P, G-prevG)
				)
			case .DaiYuan:
				return(
					inner_product(G, G),
					inner_product(P, prevG-G)
				)
			}
		}(condition, P, prevG, G)
		if let m: Float = fraction.0.array.first, M: Float = fraction.1.array.first {
			let β: Float = max(0, m/M)
			( G + ( (isinf(β)||isnan(β)) ? 0 : β ) * P ).getBytes(p)
		} else {
			assertionFailure()
		}
		return P
	}
}