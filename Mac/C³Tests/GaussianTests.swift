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
class GaussianTests: XCTestCase {

	func testSynthesize() {
		let N: Int = 16
		let L: Int = 64
		let data: [([Float], [Float], [Float])] = (0..<N).map {(_)in
			(
				(0..<L).map{(_)in Float(arc4random())/Float(UInt32.max)},
				(0..<L).map{(_)in Float(arc4random())/Float(UInt32.max)},
				(0..<L).map{(_)in Float(arc4random())/Float(UInt32.max)}
			)
		}
		
		//GaussianDistribution.synthesize(χ: <#T##[Float]#>, μ: <#T##[Float]#>, λ: <#T##[Float]#>, refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)])
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
		
		GaussianDistribution.rng(χ, ψ: ψ, μ: LaMatrice(μ, rows: 1024, cols: 1024, deallocator: nil), σ: LaMatrice(σ, rows: 1024, cols: 1024, deallocator: nil))
		
		let(dstμ, dstσ) = GaussianDistribution.est(χ)
		
		print(srcμ, dstμ)
		print(srcσ, dstσ)
		
		let rmseμ: Float = ( srcμ - dstμ ) * ( srcμ - dstμ )
		let rmseσ: Float = ( srcσ - dstσ ) * ( srcσ - dstσ )
		XCTAssert(rmseμ < 1e-3)
		XCTAssert(rmseσ < 1e-3)
    }

}
