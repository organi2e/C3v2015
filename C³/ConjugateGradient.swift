//
//  ConjugateGradient.swift
//  C³
//
//  Created by Kota Nakano on 8/30/16.
//
//
import Foundation
internal class ConjugateGradient {
	internal enum Type {
		case FletcherReeves
		case FR
		case PolakRibière
		case PR
		case HestenesStiefe
		case HS
		case DaiYuan
		case DY
	}
	private let p: [Float]
	private let g: [Float]
	private let β: (LaObjet,(LaObjet,LaObjet)) -> Float
	private var P: LaObjet {
		return LaMatrice(p, rows: p.count, cols: 1, deallocator: nil)
	}
	private var prevG: LaObjet {
		return LaMatrice(g, rows: g.count, cols: 1, deallocator: nil)
	}
	init(dim: Int, type: Type){
		p = [Float](count: dim, repeatedValue: 0)
		g = [Float](count: dim, repeatedValue: 0)
		switch type {
		case .FletcherReeves, .FR:
			β = ConjugateGradient.FR
		case .PolakRibière, .PR:
			β = ConjugateGradient.PR
		case .HestenesStiefe, .HS:
			β = ConjugateGradient.HS
		case .DaiYuan, .DY:
			β = ConjugateGradient.DY
		}
	}
	static private func FR(P: LaObjet, G: (curr: LaObjet, prev: LaObjet)) -> Float {
		if let
			m: Float = inner_product(G.curr, G.curr).array.first,
			M: Float = inner_product(G.prev, G.prev).array.first
		where 0 < abs(m) && 0 < abs(M) {
			let β: Float = m / M
			return isinf(β) || isnan(β) ? 0 : β
		}
		return 0
	}
	static private func PR(P: LaObjet, G: (curr: LaObjet, prev: LaObjet)) -> Float {
		if let
			m: Float = inner_product(G.curr, G.curr-G.prev).array.first,
			M: Float = inner_product(G.prev, G.prev).array.first
		where 0 < abs(m) && 0 < abs(M) {
			let β: Float = m / M
			return isinf(β) || isnan(β) ? 0 : max(0, β)
		}
		return 0
	}
	static private func HS(P: LaObjet, G: (curr: LaObjet, prev: LaObjet)) -> Float {
		if let
			m: Float = inner_product(G.curr, G.curr-G.prev).array.first,
			M: Float = inner_product(P, G.prev-G.curr).array.first
		where 0 < abs(m) && 0 < abs(M) {
			let β: Float = m / M
			return isinf(β) || isnan(β) ? 0 : max(0, β)
		}
		return 0
	}
	static private func DY(P: LaObjet, G: (curr: LaObjet, prev: LaObjet)) -> Float {
		if let
			m: Float = inner_product(G.curr, G.curr).array.first,
			M: Float = inner_product(P, G.prev-G.curr).array.first
		where 0 < abs(m) && 0 < abs(M) {
			let β: Float = m / M
			return isinf(β) || isnan(β) ? 0 : max(0, β)
		}
		return 0
	}
}
extension ConjugateGradient: GradientOptimizer {
	func optimize(Δx G: LaObjet, x: LaObjet) -> LaObjet {
		defer {
			G.getBytes(g)
		}
		( G + β(P, (G, prevG)) * P ).getBytes(p)
		return P
	}
}