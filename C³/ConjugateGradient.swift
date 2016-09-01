//
//  ConjugateGradient.swift
//  C³
//
//  Created by Kota Nakano on 8/30/16.
//
//	referrence: http://people.cs.vt.edu/~asandu/Public/Qual2011/Optim/Hager_2006_CG-survey.pdf
//				http://ci.nii.ac.jp/els/110009437640.pdf?id=ART0009915023&type=pdf&lang=en&host=cinii&order_no=&ppv_type=0&lang_sw=&no=1472708641&cp=
//				http://ci.nii.ac.jp/els/110009437640.pdf?id=ART0009915023&type=pdf&lang=en&host=cinii&order_no=&ppv_type=0&lang_sw=&no=1472708641&cp=
import Accelerate
public class ConjugateGradient {
	private static let η: Float = 1
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
	private let η: Float
	private let p: [Float]
	private let g: [Float]
	private let β: (LaObjet,(LaObjet,LaObjet)) -> Float
	private var P: LaObjet {
		return LaMatrice(p, rows: p.count, cols: 1, deallocator: nil)
	}
	private var prevG: LaObjet {
		return LaMatrice(g, rows: g.count, cols: 1, deallocator: nil)
	}
	init(dim: Int, η n: Float = η, type: Type){
		η = n
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
	static func factory(type: Type, η: Float = η) -> Int -> GradientOptimizer {
		return {
			ConjugateGradient(dim: $0, η: η, type: type)
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
		/*???
		if let
			yy: Float = inner_product(Y, Y).array.first,
			gy: Float = inner_product(G.curr, Y).array.first,
			dy: Float = inner_product(P, Y).array.first,
			gd: Float = inner_product(G.curr, P).array.first
		where 0 != dy {
			let λ: Float = 0.5
			let A: Float = gy / dy
			let B: Float = yy * gd / dy / dy
			let β: Float = λ * B - A
			return isinf(β) || isnan(β) ? 0 : max(0, β)
		}
		*/
		/*
		if let
			yy: Float = inner_product(Y, Y).array.first,
			gy: Float = inner_product(G.curr, Y).array.first,
			dy: Float = inner_product(P, Y).array.first,
			gd: Float = inner_product(G.curr, P).array.first
		where 0 != dy {
			let λ: Float = 0.5
			let A: Float = gy / dy
			let B: Float = yy * gd / dy / dy
			let β: Float = λ * B - A
			return isinf(β) || isnan(β) ? 0 : max(0, β)
		}
		*/
		if let
			m: Float = inner_product(Y, Y).array.first,
			M: Float = inner_product(P, Y).array.first
		where 0 != M {
			let A: LaObjet = ( Y + 2 * ( m / M ) * P )
			let B: LaObjet = ( 1 / M ) * G.curr
			if let β: Float = inner_product(A, B).array.first where !isinf(β) && !isnan(β) {
				return isinf(β) || isnan(β) ? 0 : max(0, β)
			}
		}
		return 0
	}
	static private func YGL(P: LaObjet, G: (curr: LaObjet, prev: LaObjet)) -> Float {
		let Y: LaObjet = G.curr - G.prev
		if let
			yy: Float = inner_product(Y, Y).array.first,
			gd: Float = inner_product(G.curr, P).array.first,
			gg: Float = inner_product(G.prev, G.prev).array.first
		where 0 != gg {
			let λ: Float = 0.5
			let β: Float = PR(P, G: G) + λ * yy * gd / gg / gg
			return isinf(β) || isnan(β) ? 0 : max(0, β)
		}
		return 0
	}
}
extension ConjugateGradient: GradientOptimizer {
	public func optimize(Δx G: LaObjet, x: LaObjet) -> LaObjet {
		defer {
			G.getBytes(g)
		}
		( G + β(P, (G, prevG)) * P ).getBytes(p)
		return η * P
	}
	public func reset() {
		vDSP_vclr(UnsafeMutablePointer<Float>(p), 1, vDSP_Length(p.count))
		vDSP_vclr(UnsafeMutablePointer<Float>(p), 1, vDSP_Length(p.count))
	}
}