//
//  Cauchy.swift
//  C³
//
//  Created by Kota Nakano on 8/19/16.
//
//
import Accelerate
import Metal
import CoreData

internal class Cauchy: Art {
	
}
extension Cauchy {
	internal override class var shuffleKernel: String { return "cauchyShuffle" }
}
extension Cauchy {
	internal static func pdf(pdf: [Float], μ: [Float], σ: [Float]) {
	
	}
	internal static func cdf(cdf: [Float], μ: [Float], σ: [Float]) {
	
	}
	internal static func rng(n: [Float], μ: [Float], σ: [Float]) {
		
	}
}