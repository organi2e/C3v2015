//
//  Adam.swift
//  C³
//
//  Created by Kota Nakano on 8/31/16.
//
//
import Accelerate
internal class Adam {
	private static let α: Float = 1e-3
	private static let β1: Float = 0.9
	private static let β2: Float = 0.999
	private static let ε: Float = 1e-24
	private let α: Float
	private let β1: Float
	private let β2: Float
	private let ε: Float
	private let Μd: [Float]
	private let Σd: [Float]
	private let iσd: [Float]
	private var k: Int
	private var Μ: LaObjet {
		return LaMatrice(Μd, rows: Μd.count, cols: 1, deallocator: nil)
	}
	private var Σ: LaObjet {
		return LaMatrice(Σd, rows: Σd.count, cols: 1, deallocator: nil)
	}
	private var μ: LaObjet {
		return (1/(1 - pow(β1, Float(k)))) * Μ
	}
	private var iσ: LaObjet {
		(1/(1 - pow(β2, Float(k))) * Σ + ε).getBytes(iσd)
		vvrsqrtf(UnsafeMutablePointer<Float>(iσd), iσd, [Int32(iσd.count)])
		return LaMatrice(iσd, rows: iσd.count, cols: 1, deallocator: nil)
	}
	init(dim: Int, α a: Float = α, β1 b1: Float = β1, β2 b2: Float = β2, ε e: Float = ε) {
		k = 0
		α = a
		β1 = b1
		β2 = b2
		ε = e
		iσd = [Float](count: dim, repeatedValue: 0)
		Μd = [Float](count: dim, repeatedValue: 0)
		Σd = [Float](count: dim, repeatedValue: 0)
	}
	static func factory(α α: Float = α, β1: Float = β1, β2: Float = β2, ε: Float = ε) -> Int -> GradientOptimizer {
		return {
			Adam(dim: $0, α: α, β1: β1, β2: β2, ε: ε)
		}
	}
}
extension Adam: GradientOptimizer {
	func optimize(Δx g: LaObjet, x: LaObjet) -> LaObjet {
		k = k + 1
		(β1*Μ+(1-β1)*g).getBytes(Μd)
		(β2*Σ+(1-β2)*(g*g)).getBytes(Σd)
		return μ * iσ
	}
	func reset() {
		k = 0
		vDSP_vclr(UnsafeMutablePointer<Float>(Μd), 1, vDSP_Length(Μd.count))
		vDSP_vclr(UnsafeMutablePointer<Float>(Σd), 1, vDSP_Length(Σd.count))
	}
}