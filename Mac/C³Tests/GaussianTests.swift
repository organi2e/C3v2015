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

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
	
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testRNG() {
		let srcμ: Float = Float(arc4random())/Float(UInt32.max) * 2.0 - 1.0
		let srcσ: Float = 1.0 + Float(arc4random())/Float(UInt32.max)
		let μ: LaObjet = matrix(srcμ, rows: 256, cols: 256)
		let σ: LaObjet = matrix(srcσ, rows: 256, cols: 256)
		let χ: LaObjet = GaussianDistribution.rng(μ: μ, σ: σ)
		let(dstμ, dstσ) = GaussianDistribution.est(χ)
		let rmseμ: Float = ( srcμ - dstμ ) * ( srcμ - dstμ )
		let rmseσ: Float = ( srcσ - dstσ ) * ( srcσ - dstσ )
		XCTAssert(rmseμ < 1e-3)
		XCTAssert(rmseσ < 1e-3)
    }

}
