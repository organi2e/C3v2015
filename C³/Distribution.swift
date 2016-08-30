//
//  Distribution.swift
//  C³
//
//  Created by Kota Nakano on 8/29/16.
//
//
public enum StableDistributionType {
	case Gauss
	case Cauchy
}
internal protocol StableDistribution {
	static func cdf(χ: Float, μ: Float, σ: Float) -> Float
	static func pdf(χ: Float, μ: Float, σ: Float) -> Float
//	static func cdf(χ: LaObjet, μ: LaObjet, σ: LaObjet) -> LaObjet
//	static func pdf(χ: LaObjet, μ: LaObjet, σ: LaObjet) -> LaObjet
	static func rng(χ: [Float], μ: [Float], σ: [Float], ψ: [UInt32])
}
internal protocol RandomNumberGeneratable {
	var χ: LaObjet { get }
	var μ: LaObjet { get }
	var σ: LaObjet { get }
	func shuffle(dist: StableDistribution.Type)
}