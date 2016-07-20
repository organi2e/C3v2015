//
//  Eval.swift
//  Mac
//
//  Created by Kota Nakano on 7/15/16.
//
//
import Accelerate
import XCTest
@testable import C3

class MiscTests: XCTestCase {
	func testNormal() {
		let x: LA = LA(row: 1024, col: 4)
		XCTAssert(la_status(x.la)==0)

		x.normal()

		let u: la_object_t = la_splat_from_float(500.0, la_attribute_t(LA.ATTR))
		XCTAssert(la_status(u)==0)

		let s: la_object_t = la_splat_from_float(100.0, la_attribute_t(LA.ATTR))
		XCTAssert(la_status(s)==0)
		
		let a: la_object_t = la_elementwise_product(s, x.la)
		XCTAssert(la_status(a)==0)

		let n: la_object_t = la_sum(a, u)
		XCTAssert(la_status(n)==0)
		
		let N: [Float] = [Float](count: x.length, repeatedValue: 0.0)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(N), la_count_t(x.col), n)
		
		let mu: Float = N.reduce(0){$0+$1}/Float(N.count)
		let sigma: Float = sqrtf(N.map{$0-mu}.map{$0*$0}.reduce(0){$0+$1}/Float(N.count))
		//print(x.buffer, N)
		print(mu, sigma)
		
	}
}