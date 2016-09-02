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
	
	func testGrad() {
		
		let χd: [Float] = Array<Float>(arrayLiteral: 0, 1, 2, 3)
		let χ: LaObjet = LaMatrice(χd, rows: χd.count, cols: 1)
		
		let μd: [Float] = Array<Float>(arrayLiteral: 0, 1, 2, 3)
		let μ: LaObjet = LaMatrice(μd, rows: μd.count, cols: 1)
		
		let σd: [Float] = Array<Float>(arrayLiteral: 0, 1, 2, 3)
		let σ: LaObjet = LaMatrice(σd, rows: σd.count, cols: 1)
		
		let gradμ: LaObjet = CauchyDistribution.gradμ(μ: μ, χ: χ)
		let gradσ: LaObjet = CauchyDistribution.gradσ(σ: σ, χ: χ)
		
		XCTAssert(gradμ.array.elementsEqual(χ.array))
		XCTAssert(gradσ.array.elementsEqual(χ.array))
		
	}
	
	
	func testRNG() {
		
		let srcμ: Float = Float(arc4random())/Float(UInt32.max) * 2.0 - 1.0
		let srcσ: Float = 1.0 + Float(M_PI) * Float(arc4random())/Float(UInt32.max)
		
		let N: Int = 1 << 16
		let ψ: [UInt32] = [UInt32](count: N, repeatedValue: 0)
		let μ: [Float] = [Float](count: N, repeatedValue: srcμ)
		let σ: [Float] = [Float](count: N, repeatedValue: srcσ)
		let χ: [Float] = [Float](count: N, repeatedValue: 0.0)
		
		arc4random_buf(UnsafeMutablePointer<Void>(ψ), sizeof(UInt32)*N)
		
		CauchyDistribution.rng(χ, μ: μ, σ: σ, ψ: ψ)
		
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
