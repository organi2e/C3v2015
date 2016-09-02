//
//  GaussianTests.swift
//  Mac
//
//  Created by Kota Nakano on 8/29/16.
//
//
import Accelerate
import XCTest
@testable import C3
class CauchyTests: XCTestCase {
	
	func testΔ() {
		
		let Δd: [Float] = Array<Float>(arrayLiteral: 0, 1, 2, 3)
		let Δ: LaObjet = LaMatrice(Δd, rows: Δd.count, cols: 1)
		
		let μd: [Float] = Array<Float>(arrayLiteral: 0, 1, 2, 3)
		let μ: LaObjet = LaMatrice(μd, rows: μd.count, cols: 1)
		
		let σd: [Float] = Array<Float>(arrayLiteral: 0, 1, 2, 3)
		let σ: LaObjet = LaMatrice(σd, rows: σd.count, cols: 1)
		
		let Δμ: LaObjet = CauchyDistribution.Δμ(Δ: Δ, μ: μ)
		let Δσ: LaObjet = CauchyDistribution.Δσ(Δ: Δ, σ: σ)
		
		XCTAssert(Δμ.array.elementsEqual(Δ.array))
		XCTAssert(Δσ.array.elementsEqual(Δ.array))
		
	}
	
	func testGain() {
		let χd: [Float] = Array<Float>(arrayLiteral: 0, 1, 2, 3)
		let χ: LaObjet = LaMatrice(χd, rows: χd.count, cols: 1)
		
		let weight = CauchyDistribution.gainχ(χ)
		XCTAssert(weight.0.array.elementsEqual(χd))
		XCTAssert(weight.1.array.elementsEqual(χd))
	}
	
	func testSynthesize() {
		let N: Int = 10
		let L: Int = 64
		let refer: [([Float], [Float], [Float])] = (0..<N).map {(_)in
			(
				(0..<L).map{(_)in Float(arc4random())/Float(uint32.max)},
				(0..<L).map{(_)in Float(arc4random())/Float(uint32.max)},
				(0..<L).map{(_)in Float(arc4random())/Float(uint32.max)}
			)
		}
		let χ: [Float] = [Float](count: L, repeatedValue: 0)
		let μ: [Float] = [Float](count: L, repeatedValue: 0)
		let λ: [Float] = [Float](count: L, repeatedValue: 0)
	}
	
	func testRNG() {
		
		let srcμ: Float = Float(arc4random())/Float(UInt32.max) * 2.0 - 1.0
		let srcσ: Float = 1.0 + Float(M_PI) * Float(arc4random())/Float(UInt32.max)
		
		let N: Int = 1024 * 1024
		let ψ: [UInt32] = [UInt32](count: N, repeatedValue: 0)
		let μ: [Float] = [Float](count: N, repeatedValue: srcμ)
		let σ: [Float] = [Float](count: N, repeatedValue: srcσ)
		let χ: [Float] = [Float](count: N, repeatedValue: 0.0)
		
		arc4random_buf(UnsafeMutablePointer<Void>(ψ), sizeof(UInt32)*N)
		
		CauchyDistribution.rng(χ, ψ: ψ, μ: LaMatrice(μ, rows: 1024, cols: 1024, deallocator: nil), σ: LaMatrice(σ, rows: 1024, cols: 1024, deallocator: nil))
		
		let(dstμ, dstσ) = CauchyDistribution.est(χ, η: 0.8, K: 1024)
		
		print(srcμ, dstμ)
		print(srcσ, dstσ)
		
		let rmseμ: Float = ( srcμ - dstμ ) * ( srcμ - dstμ )
		let rmseσ: Float = ( srcσ - dstσ ) * ( srcσ - dstσ )
		
		XCTAssert(!isinf(rmseμ))
		XCTAssert(!isnan(rmseμ))
		XCTAssert(!isinf(rmseσ))
		XCTAssert(!isnan(rmseσ))
		
		XCTAssert(rmseμ < 1e-2)
		XCTAssert(rmseσ < 1e-2)
		
	}
	
}
