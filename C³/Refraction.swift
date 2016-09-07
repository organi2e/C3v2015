//
//  Refraction.swift
//  C³
//
//  Created by Kota Nakano on 9/6/16.
//
//
import Accelerate
import simd
public class Refraction {
	private static let r: Float = 0.5
	private static let η: Float = 0.5
	private let r: Float
	private let η: Float
	private var w: [Float]
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
		let ll = float2.init(W.array)
		let nn = -normalize(float2.init(Δw.array))
		let N: LaObjet = L2Normalize(Δw)
		let L: LaObjet = W
		let LN: LaObjet = inner_product(L, N)
		if let c: Float = LN.array.first {
			print(ll, nn)
			let j: Float = 1 - r * r * ( 1 - c * c )
			
			print(j)
			if 0 < j {
				let tt = refract(ll, n: nn, eta: r)
				w[0] = tt.x
				w[1] = tt.y
				return η * W
				
				let T: LaObjet = r * L + ( r * c - sqrt( j ) ) * N
				(T).getBytes(w)
				if w.count == 2 {
					let nn = float2.init(N.array)
					let tt = refract(ll, n: nn, eta: r)
					print(w)
					print(tt)
				}
				return η * W
			} else {
				let tt = reflect(ll, n: nn)
				w[0] = tt.x
				w[1] = tt.y
				return η * W
				
				let T: LaObjet = L - 2 * c * N
				(T).getBytes(w)
				return η * W
			}
		}
		L2Normalize(Δw).getBytes(w)
		return η * W
	}
	public func reset() {
		vDSP_vclr(UnsafeMutablePointer<Float>(w), 1, vDSP_Length(w.count))
	}
}