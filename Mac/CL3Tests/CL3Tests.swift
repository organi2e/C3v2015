//
//  CL3Tests.swift
//  CL3Tests
//
//  Created by Kota Nakano on 8/25/16.
//
//
import Accelerate
import XCTest
@testable import CL3

class CL3Tests: XCTestCase {

	let NOHINT = la_hint_t(LA_NO_HINT)
	let ATTR = la_attribute_t(LA_DEFAULT_ATTRIBUTES)
	
	func testLA() {
		
		let I: Int = 256
		let J: Int = 256
		let K: Int = 256
		
		let a: [Float] = (0..<I*J).map {(_)in Float(arc4random())/Float(UInt32.max) }
		let b: [Float] = (0..<J*K).map {(_)in Float(arc4random())/Float(UInt32.max) }
		let dst: [Float] = [Float](count: I*K, repeatedValue: 0)
		
		let LA: la_object_t = la_matrix_from_float_buffer(a, la_count_t(I), la_count_t(J), la_count_t(J), NOHINT, ATTR)
		let LB: la_object_t = la_matrix_from_float_buffer(b, la_count_t(I), la_count_t(J), la_count_t(J), NOHINT, ATTR)
		
		measureBlock {
			(0..<16).forEach {(_)in
				let LC: la_object_t = la_matrix_product(LA, LB)
				la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(dst), la_count_t(K), LC)
			}
		}
		
	}
    func testCL() {
		var x: context_t = context_t()
		
		context_init(&x);
		
		let I: Int = 1024
		let J: Int = 1024
		let K: Int = 1024
		
		let a: [Float] = (0..<I*J).map {(_)in Float(arc4random())/Float(UInt32.max) }
		let b: [Float] = (0..<J*K).map {(_)in Float(arc4random())/Float(UInt32.max) }
		let c: [Float] = [Float](count: I*K, repeatedValue: 0)
		
		let A = context_newBuffer(&x, sizeof(Float)*I*J, UnsafeMutablePointer<Void>(a));
		let B = context_newBuffer(&x, sizeof(Float)*J*K, UnsafeMutablePointer<Void>(b));
		let C = context_newBuffer(&x, sizeof(Float)*I*K, UnsafeMutablePointer<Void>(c));
		
		let LA: la_object_t = la_matrix_from_float_buffer(a, la_count_t(I), la_count_t(J), la_count_t(J), NOHINT, ATTR)
		let LB: la_object_t = la_matrix_from_float_buffer(b, la_count_t(I), la_count_t(J), la_count_t(J), NOHINT, ATTR)
		measureBlock {
			(0..<16).forEach {(_)in
				context_gemm(&x, C, A, B, Int32(I), Int32(J), Int32(K))
			}
			clFinish(x.queue.memory)
		}
		
		clEnqueueReadBuffer(x.queue.memory, A, cl_bool(1), 0, sizeof(Float)*I*K, UnsafeMutablePointer<Void>(c), 0, nil, nil)
		clFinish(x.queue.memory)
		clFlush(x.queue.memory)
		
		context_finalize(&x);
		
		let srcla = la_matrix_from_float_buffer(c, la_count_t(I), la_count_t(K), la_count_t(K), NOHINT, ATTR)
		let dstla = la_matrix_product(LA, LB)
		
		let rmse = la_norm_as_float(la_difference(srcla, dstla), la_norm_t(LA_L2_NORM))
		XCTAssert(!isnan(rmse))
		XCTAssert(!isinf(rmse))
		XCTAssert(1e-5 > rmse)
		print(rmse)
		
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
	
    
}
