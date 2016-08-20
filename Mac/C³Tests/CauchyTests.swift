//
//  artTests.swift
//  Mac
//
//  Created by Kota Nakano on 8/19/16.
//
//
import Accelerate
import XCTest
@testable import C3

class CauchyTests: XCTestCase {
	let NOHINT: la_hint_t = la_hint_t(LA_NO_HINT)
	let ATTR: la_attribute_t = la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)
	let context: Context = try!Context()
	func testRefresh() {
		
		guard let art: Cauchy = context.new() else {
			XCTFail()
			return
		}
		
		let d_mu: Float = Float(arc4random_uniform(1024))/64.0
		let d_sigma: Float = Float(256+arc4random_uniform(256))/256.0
		
		let rows: Int = 64//*Int(1+arc4random_uniform(256))
		let cols: Int = 64//*Int(1+arc4random_uniform(256))
		
		art.resize(rows: rows, cols: cols)
		art.adjust(mu: d_mu, sigma: d_sigma)
		art.setup()
		
		var e_mu: Float = 1.0
		var e_gamma: Float = 1.0
		let eps: Float = 1.0/16.0
		let K: Int = rows * cols
		
		art.shuffle()
		
		for _ in 0..<4096 {
			
			let value: la_object_t = context.toLAObject(art.value, rows: rows*cols, cols: 1)
			
			context.join()
			
			let X: [Float] = [Float](count: rows*cols, repeatedValue: 0.0)
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(X), 1, value)
			
			art.shuffle()
			
			var mean: Float = 0
			
			let U: [Float] = [Float](count: K, repeatedValue: 0)
			let A: [Float] = [Float](count: K, repeatedValue: 0)
			let B: [Float] = [Float](count: K, repeatedValue: 0)
			let C: [Float] = [Float](count: K, repeatedValue: 0)
			
			vDSP_vsadd(X, 1, [-e_mu], UnsafeMutablePointer<Float>(U), 1, vDSP_Length(K))
			vDSP_vsq(U, 1, UnsafeMutablePointer<Float>(B), 1, vDSP_Length(K))
			vDSP_vsadd(B, 1, [e_gamma*e_gamma], UnsafeMutablePointer<Float>(B), 1, vDSP_Length(K))
			
			vDSP_vsmul(U, 1, [2.0*e_mu], UnsafeMutablePointer<Float>(A), 1, vDSP_Length(K))
			vDSP_vdiv(B, 1, A, 1, UnsafeMutablePointer<Float>(C), 1, vDSP_Length(K))
			vDSP_meanv(C, 1, &mean, vDSP_Length(K))
			
			e_mu = e_mu + eps * mean
			
			vDSP_svdiv([2.0*e_gamma], B, 1, UnsafeMutablePointer<Float>(C), 1, vDSP_Length(K))
			vDSP_meanv(C, 1, &mean, vDSP_Length(K))
			
			e_gamma = e_gamma + eps * ( 1 / e_gamma - mean )
			
		}
		
		XCTAssert(!isinf(e_mu))
		XCTAssert(!isinf(e_mu))
		if abs(log(e_mu)-log(d_mu)) > 0.1 {
			XCTFail("\(e_mu) vs \(d_mu)")
		}
		
		XCTAssert(!isinf(e_gamma))
		XCTAssert(!isinf(e_gamma))
		if abs(log(e_gamma)-log(d_sigma)) > 0.5 {
			XCTFail("\(e_gamma) vs \(d_sigma)")
		}
		
	}
}
