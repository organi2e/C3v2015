//
//  Distribution.swift
//  C³
//
//  Created by Kota Nakano on 8/29/16.
//
//
import Accelerate
public enum DistributionType: String {
	case Gauss = "Gauss"
	case Cauchy = "Cauchy"
	case False = "False"
}
internal protocol Distribution {
	static func cdf(χ: Float, μ: Float, σ: Float) -> Float
	static func pdf(χ: Float, μ: Float, σ: Float) -> Float
//	static func cdf(χ: LaObjet, μ: LaObjet, σ: LaObjet) -> LaObjet
//	static func pdf(χ: LaObjet, μ: LaObjet, σ: LaObjet) -> LaObjet
	static func rng(χ: [Float], μ: [Float], σ: [Float], ψ: [UInt32])
	static func synthesize(χ χ: [Float], μ: [Float], λ: [Float], refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)])
}
internal class FalseDistribution: Distribution {
	static func cdf(χ: Float, μ: Float, σ: Float) -> Float { return 0 }
	static func pdf(χ: Float, μ: Float, σ: Float) -> Float { return 0 }
	//	static func cdf(χ: LaObjet, μ: LaObjet, σ: LaObjet) -> LaObjet
	//	static func pdf(χ: LaObjet, μ: LaObjet, σ: LaObjet) -> LaObjet
	static func rng(χ: [Float], μ: [Float], σ: [Float], ψ: [UInt32]) {
		vDSP_vfill([Float.quietNaN], UnsafeMutablePointer<Float>(χ), 1, vDSP_Length(χ.count))
	}
	static func synthesize(χ χ: [Float], μ: [Float], λ: [Float], refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)]) {
		vDSP_vfill([Float.quietNaN], UnsafeMutablePointer<Float>(χ), 1, vDSP_Length(χ.count))
		vDSP_vfill([Float.quietNaN], UnsafeMutablePointer<Float>(μ), 1, vDSP_Length(μ.count))
		vDSP_vfill([Float.infinity], UnsafeMutablePointer<Float>(λ), 1, vDSP_Length(λ.count))
	}
}
internal protocol RandomNumberGeneratable {
	var χ: LaObjet { get }
	var μ: LaObjet { get }
	var σ: LaObjet { get }
	func shuffle(dist: Distribution.Type)
}
