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
		let μ: LaObjet = matrix(-3.0, rows: 256, cols: 256)
		let σ: LaObjet = matrix(3.0, rows: 256, cols: 256)
		let n: LaObjet = GaussianDistribution.rng(μ: μ, σ: σ)
		var mean: Float = 0
		vDSP_meanv(n.array, 1, &mean, vDSP_Length(n.count))
		
		print(mean)
		
		let fp = fopen("/tmp/gaussian.raw", "wb")
		fwrite(n.array, sizeof(Float), n.count, fp)
		fclose(fp)
    }

}
