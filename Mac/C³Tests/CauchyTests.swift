//
//  artTests.swift
//  Mac
//
//  Created by Kota Nakano on 8/19/16.
//
//
import Accelerate
import XCTest
import simd
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
		
		let dμ: Float = Float(arc4random_uniform(1024))/64.0
		let dσ: Float = Float(256+arc4random_uniform(256))/256.0
		
		let rows: Int = 64//*Int(1+arc4random_uniform(256))
		let cols: Int = 64//*Int(1+arc4random_uniform(256))
		
		//art.resize(rows: rows, cols: cols)
		art.adjust(μ: dμ, σ: dσ)
		
		let eps: Float = 0.5
		let K: Int = rows * cols
		
		let eye: float2x2 = float2x2(diagonal: float2(1))
		
		var est: float2 = float2(1)
		var H: float2x2 = eye
		
		var p_est: float2 = est
		var p_delta: float2 = float2(0)

		art.shuffle()
		
		for k in 0..<1024 {

			let χ: la_object_t = context.toLAObject(art.χ, rows: rows*cols, cols: 1)
			
			let X: [Float] = [Float](count: rows*cols, repeatedValue: 0.0)

			context.join()
			art.shuffle()
			
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(X), 1, χ)
			
			if k == 0 {
				let fp = fopen("/tmp/cauchy.raw", "wb")
				fwrite(X, sizeof(Float), X.count, fp)
				fclose(fp)
			}
			
			var mean: Float = 0
			
			let U: [Float] = [Float](count: K, repeatedValue: 0)
			let A: [Float] = [Float](count: K, repeatedValue: 0)
			let B: [Float] = [Float](count: K, repeatedValue: 0)
			let C: [Float] = [Float](count: K, repeatedValue: 0)
			
			vDSP_vsadd(X, 1, [-est.x], UnsafeMutablePointer<Float>(U), 1, vDSP_Length(K))
			vDSP_vsq(U, 1, UnsafeMutablePointer<Float>(B), 1, vDSP_Length(K))
			vDSP_vsadd(B, 1, [est.y*est.y], UnsafeMutablePointer<Float>(B), 1, vDSP_Length(K))
			
			vDSP_vsmul(U, 1, [2.0*est.x], UnsafeMutablePointer<Float>(A), 1, vDSP_Length(K))
			vDSP_vdiv(B, 1, A, 1, UnsafeMutablePointer<Float>(C), 1, vDSP_Length(K))
			vDSP_meanv(C, 1, &mean, vDSP_Length(K))
			
			var delta: float2 = float2(0)
			
			delta.x = mean
			
			vDSP_svdiv([2.0*est.y], B, 1, UnsafeMutablePointer<Float>(C), 1, vDSP_Length(K))
			vDSP_meanv(C, 1, &mean, vDSP_Length(K))
			
			delta.y = 1 / est.y - mean
			
			let s: float2 = est - p_est
			let y: float2 = delta - p_delta
			let m: Float = dot(y, s)
			
			if 1e-8 < abs(m) {//BFGS
				let rho: Float = 1.0 / m
				let S: float2x2 = float2x2([s, float2(0)])
				let Y: float2x2 = float2x2(rows: [y, float2(0)])
				let A: float2x2 = eye - rho * S * Y
				let B: float2x2 = A.transpose
				let C: float2x2 = S * S.transpose
				H = A * H * B + C
				delta = -H * delta
			}
			
			p_est = est
			p_delta = delta
			
			est = est + eps * delta
			est = abs(est)
			
		}
		
		XCTAssert(!isinf(est.x))
		XCTAssert(!isnan(est.x))
		if abs(log(est.x)-log(dμ)) > 0.1 {
			XCTFail("\(est.x) vs \(dμ)")
		}
		
		XCTAssert(!isinf(est.y))
		XCTAssert(!isnan(est.y))
		if abs(log(est.y)-log(dσ)) > 0.5 {
			XCTFail("\(est.y) vs \(dσ)")
		}
		
	}
}
