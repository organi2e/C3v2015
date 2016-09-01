//
//  SMORMS3.swift
//  C³
//
//  Created by Kota Nakano on 8/31/16.
//
//
import Accelerate
public class SMORMS3 {
	private static let α: Float = 1e-3
	private static let ε: Float = 1e-16
	private let α: Float
	private let ε: Float
	private let mem: [Float]
	private let g: [Float]
	private let g2: [Float]
	private var x: [Float]
	private var m: [Float]
	private var MEM: LaObjet {
		return LaMatrice(mem, rows: mem.count, cols: 1)
	}
	private var G: LaObjet {
		return LaMatrice(g, rows: g.count, cols: 1)
	}
	private var G2: LaObjet {
		return LaMatrice(g2, rows: g2.count, cols: 1)
	}
	private var X: LaObjet {
		return LaMatrice(x, rows: x.count, cols: 1)
	}
	private var M: LaObjet {
		return LaMatrice(m, rows: m.count, cols: 1)
	}
	init(dim: Int, α a: Float = α, ε e: Float = ε) {
		α = a
		ε = e
		mem = [Float](count: dim, repeatedValue: 1)
		g = [Float](count: dim, repeatedValue: 0)
		g2 = [Float](count: dim, repeatedValue: 0)
		x = [Float](count: dim, repeatedValue: 0)
		m = [Float](count: dim, repeatedValue: 0)
	}
	static func factory(α α: Float = α, ε: Float = ε) -> Int -> GradientOptimizer {
		return {
			SMORMS3(dim: $0, α: α, ε: ε)
		}
	}
}
extension SMORMS3: GradientOptimizer {
	public func optimize(Δx grad: LaObjet, x _: LaObjet) -> LaObjet {
		let r: LaObjet = 1 / ( 1 + MEM )
		((1-r) * G + r * grad).getBytes(g)
		((1-r) * G2 + r * grad * grad).getBytes(g2)
		(1+MEM*(1-G*G/(G2+ε))).getBytes(mem)
		(G*G).getBytes(x)
		//vDSP_vsq(g, 1, UnsafeMutablePointer<Float>(x), 1, vDSP_Length(min(x.count, g.count)))
		vvdivf(UnsafeMutablePointer<Float>(x), x, g2, [Int32(min(x.count, g2.count))])
		//vDSP_vthr(x, 1, [α], UnsafeMutablePointer<Float>(x), 1, vDSP_Length(x.count))
		vvrsqrtf(UnsafeMutablePointer<Float>(m), g2, [Int32(min(m.count, g2.count))])
		//for k in 0..<x.count { x[k] = min(α, g[k]*g[k]/(g2[k]+ε)) }
		//for k in 0..<x.count { x[k] = min(α, g[k]*g[k]/(g2[k]+ε))/(sqrt(g2[k])+ε) }
		return grad * M * X
	}
	public func reset() {
		vDSP_vfill([Float(1)], UnsafeMutablePointer<Float>(mem), 1, vDSP_Length(mem.count))
		vDSP_vclr(UnsafeMutablePointer<Float>(g), 1, vDSP_Length(g.count))
		vDSP_vclr(UnsafeMutablePointer<Float>(g2), 1, vDSP_Length(g2.count))
		vDSP_vclr(UnsafeMutablePointer<Float>(x), 1, vDSP_Length(x.count))
		vDSP_vclr(UnsafeMutablePointer<Float>(m), 1, vDSP_Length(m.count))
	}
}