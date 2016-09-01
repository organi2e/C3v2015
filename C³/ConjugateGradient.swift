//
//  ConjugateGradient.swift
//  C³
//
//  Created by Kota Nakano on 8/30/16.
//
//	referrence: http://people.cs.vt.edu/~asandu/Public/Qual2011/Optim/Hager_2006_CG-survey.pdf
import Foundation
public class ConjugateGradient {
	public enum Type {
		case FletcherReeves
		case PolakRibière
		case HestenesStiefe
		case DaiYuan
		case ConjugateDescent
		case LiuStorey
		case HagerZhang
	}
	public static let types = (
		FR: Type.FletcherReeves,
		PR: Type.PolakRibière,
		HS: Type.HestenesStiefe,
		CD: Type.ConjugateDescent,
		LS: Type.LiuStorey,
		DY: Type.DaiYuan,
		HZ: Type.HagerZhang
	)
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
		case .FletcherReeves:
			β = self.dynamicType.FR
		case .PolakRibière:
			β = self.dynamicType.PR
		case .HestenesStiefe:
			β = self.dynamicType.HS
		case .ConjugateDescent:
			β = self.dynamicType.CD
		case .LiuStorey:
			β = self.dynamicType.LS
		case .DaiYuan:
			β = self.dynamicType.DY
		case .HagerZhang:
			β = self.dynamicType.HZ
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
	static private func CD(P: LaObjet, G: (curr: LaObjet, prev: LaObjet)) -> Float {
		if let
			m: Float = inner_product(G.curr, G.curr).array.first,
			M: Float = inner_product(P, G.prev).array.first
		where 0 < abs(m) && 0 < abs(M) {
			let β: Float = m / M
			return isinf(β) || isnan(β) ? 0 : max(0, β)
		}
		return 0
	}
	static private func LS(P: LaObjet, G: (curr: LaObjet, prev: LaObjet)) -> Float {
		if let
			m: Float = inner_product(G.curr, G.prev-G.curr).array.first,
			M: Float = inner_product(P, G.prev).array.first
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
	static private func HZ(P: LaObjet, G: (curr: LaObjet, prev: LaObjet)) -> Float {
		let Y: LaObjet = G.curr - G.prev
		if let
			m: Float = inner_product(Y, Y).array.first,
			M: Float = inner_product(P, Y).array.first
		where 0 != M {
			let A: LaObjet = ( Y - 2 * ( m / M ) * P )
			let B: LaObjet = ( 1 / M ) * G.curr
			if let β: Float = inner_product(A, B).array.first where !isinf(β) && !isnan(β) {
				return isinf(β) || isnan(β) ? 0 : max(0, β)
			}
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