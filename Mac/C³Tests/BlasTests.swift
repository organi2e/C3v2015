//
//  EdgeTests.swift
//  Mac
//
//  Created by Kota Nakano on 6/7/16.
//
//
import Accelerate
import Foundation
import XCTest
@testable import C3
class BlasTests: XCTestCase {
	let NOHINT: la_hint_t = la_hint_t(LA_NO_HINT)
	let ATTR: la_attribute_t = la_attribute_t(LA_DEFAULT_ATTRIBUTES)
	let context: Context = try!Context()
	/*
	func testShuffle() {
		let rows: Int = 8
		let cols: Int = 12
		let l: la_object_t = la_matrix_from_float_buffer((0..<rows*cols).map{Float($0)}, UInt(rows), UInt(cols), UInt(cols), NOHINT, ATTR)
		let m: MTLBuffer = context.fromLAObject(l)
		let r: la_object_t = context.toLAObject(m, rows: rows, cols: cols)
		context.join()

		let b: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(m.contents()), count: rows*cols)
		print("enc")
		for row in (0..<rows) {
			for col in (0..<cols) {
				print(b[row*cols+col], terminator: ", ")
			}
			print("\r\n", terminator: "")
		}
		print("dec")
		la_matrix_to_float_buffer(b.baseAddress, UInt(1), r)
		for row in (0..<rows) {
			for col in (0..<cols) {
				print(b[row*cols+col], terminator: ", ")
			}
			print("\r\n", terminator: "")
		}
	}
	*/
	/*
	func testCPUOuter() {
		let rows: Int = 256
		let cols: Int = 256
		
		let LA: la_object_t = la_matrix_from_float_buffer((0..<rows).map{(_)in Float(arc4random_uniform(256))/Float(128.0)-1.0}, la_count_t(rows), la_count_t(1), la_count_t(1), NOHINT, ATTR)
		let LB: la_object_t = la_matrix_from_float_buffer((0..<cols).map{(_)in Float(arc4random_uniform(256))/Float(128.0)-1.0}, la_count_t(1), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		
		let cache: [Float] = [Float](count: rows*cols, repeatedValue: 0.0)
		
		measureBlock {
			(0..<16).forEach {(_)in
				let LC: la_object_t = la_matrix_product(LA, LB)
				la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(cols), LC)
			}
		}
	}
	func testCPUGEMV() {
		let rows: Int = 256
		let cols: Int = 256
		
		let LA: la_object_t = la_matrix_from_float_buffer((0..<rows*cols).map{(_)in Float(arc4random_uniform(256))/Float(128.0)-1.0}, la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		let LB: la_object_t = la_matrix_from_float_buffer((0..<rows).map{(_)in Float(arc4random_uniform(256))/Float(128.0)-1.0}, la_count_t(rows), la_count_t(1), la_count_t(1), NOHINT, ATTR)
		
		let cache: [Float] = [Float](count: rows*cols, repeatedValue: 0.0)
		
		measureBlock {
			(0..<16).forEach {(_)in
				let LC: la_object_t = la_matrix_product(LA, LB)
				la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(cols), LC)
			}
		}
		
	}
	func testCPUGEMM() {
		
		let M: Int = 200
		let K: Int = 400
		let N: Int = 800
		
		let LA: la_object_t = la_matrix_from_float_buffer((0..<M*K).map{(_)in Float(arc4random_uniform(256))/128.0-1.0}, la_count_t(M), la_count_t(K), la_count_t(K), NOHINT, ATTR)
		let LB: la_object_t = la_matrix_from_float_buffer((0..<K*N).map{(_)in Float(arc4random_uniform(256))/128.0-1.0}, la_count_t(K), la_count_t(N), la_count_t(N), NOHINT, ATTR)
		
		let cache: [Float] = [Float](count: M*N, repeatedValue: 0.0)
		
		measureBlock {
			(0..<4).forEach {(_)in
				let LC: la_object_t = la_matrix_product(LA, LB)
				la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(N), LC)
			}
		}
	}
	*/
	func testMTLOuter() {
		let rows: Int = 4 * Int(1+arc4random_uniform(256))
		let cols: Int = 4 * Int(1+arc4random_uniform(256))
		
		let LA: la_object_t = la_matrix_from_float_buffer((0..<rows).map{(_)in Float(arc4random_uniform(256))/Float(128.0)-1.0}, la_count_t(rows), la_count_t(1), la_count_t(1), NOHINT, ATTR)
		let LB: la_object_t = la_matrix_from_float_buffer((0..<cols).map{(_)in Float(arc4random_uniform(256))/Float(128.0)-1.0}, la_count_t(cols), la_count_t(1), la_count_t(1), NOHINT, ATTR)
		let LC: la_object_t = la_matrix_product(LA, la_transpose(LB))
		
		let MA: MTLBuffer = context.fromLAObject(LA)
		let MB: MTLBuffer = context.fromLAObject(LB)
		let MC: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows*cols)
		
		let bs: Int = 64
		
		let group: MTLSize = MTLSize(width: rows/4, height: 1, depth: 1)
		let local: MTLSize = MTLSize(width: bs, height: 1, depth: 1)
		
		measureBlock {
			(0..<4).forEach {(_)in
				self.context.newComputeCommand(function: "outer") {
					$0.setBuffer(MC, offset: 0, atIndex: 0)
					$0.setBuffer(MA, offset: 0, atIndex: 1)
					$0.setBuffer(MB, offset: 0, atIndex: 2)
					$0.setBytes([UInt32(rows/4), UInt32(cols/4)], length: 2*sizeof(UInt32), atIndex: 3)
					$0.setBytes([Float(1.0), Float(0.0)], length: 2*sizeof(Float), atIndex: 4)
					$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
				}
			}
			self.context.join()
		}
		let CC: la_object_t = context.toLAObject(MC, rows: rows, cols: cols)
		context.join()
		
		let E: la_object_t = la_difference(LC, CC)
		let rmse: Float = la_norm_as_float(E, la_norm_t(LA_L2_NORM))
		XCTAssert(!isnan(rmse))
		XCTAssert(!isinf(rmse))
		if 1e-9 < rmse {
			let cache: [Float] = [Float](count: rows*cols, repeatedValue: 0.0)
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(cols), E)
			for row in 0..<rows {
				print(cache[row*cols..<row*cols+cols])
			}
			XCTFail("RMSE: \(rmse)")
		}
		
	}
	func testMTLGEMM() {
		let M: Int = 4 * Int(1+arc4random_uniform(256))
		let K: Int = 4 * Int(1+arc4random_uniform(256))
		let N: Int = 4 * Int(1+arc4random_uniform(256))
		
		let LA: la_object_t = la_matrix_from_float_buffer((0..<M*K).map{(_)in Float(arc4random_uniform(256))/128.0-1.0}, la_count_t(M), la_count_t(K), la_count_t(K), NOHINT, ATTR)
		let LB: la_object_t = la_matrix_from_float_buffer((0..<K*N).map{(_)in Float(arc4random_uniform(256))/128.0-1.0}, la_count_t(K), la_count_t(N), la_count_t(N), NOHINT, ATTR)
		let LC: la_object_t = la_matrix_product(LA, LB)
		
		let MA: MTLBuffer = context.fromLAObject(LA)
		let MB: MTLBuffer = context.fromLAObject(LB)
		let MC: MTLBuffer = context.newBuffer(length: sizeof(Float)*M*N)
		
		let bs: Int = 16
		
		let group: MTLSize = MTLSize(width: (N/4-1)/bs+1, height: (M/4-1)/bs+1, depth: 1)
		let local: MTLSize = MTLSize(width: bs, height: bs, depth: 1)
		
		measureBlock {
			(0..<16).forEach {(_)in
				self.context.newComputeCommand(function: "gemm") {
					$0.setBuffer(MC, offset: 0, atIndex: 0)
					$0.setBuffer(MA, offset: 0, atIndex: 1)
					$0.setBuffer(MB, offset: 0, atIndex: 2)
					$0.setBytes([UInt32(M/4), UInt32(K/4), UInt32(N/4), UInt32(bs)], length: 4*sizeof(UInt32), atIndex: 3)
					$0.setBytes([Float(1.0),Float(0.0)], length: 2*sizeof(Float), atIndex: 4)
					$0.setThreadgroupMemoryLength(sizeof(Float)*16*bs*bs, atIndex: 0)
					$0.setThreadgroupMemoryLength(sizeof(Float)*16*bs*bs, atIndex: 1)
					$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
				}
			}
			self.context.join()
		}
		
		let CC: la_object_t = context.toLAObject(MC, rows: M, cols: N)
		context.join()
		
		
		let E: la_object_t = la_difference(LC, CC)
		let rmse: Float = la_norm_as_float(E, la_norm_t(LA_L2_NORM))
		XCTAssert(!isnan(rmse))
		XCTAssert(!isinf(rmse))
		if 1e-5 < rmse {
			let cache: [Float] = [Float](count: M*N, repeatedValue: 0.0)
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(N), E)
			for row in 0..<M {
				print(cache[row*N..<row*N+N])
			}
			XCTFail("RMSE: \(rmse)")
		}
		

		
	}
	func testMTLGEMV() {
		
		let rows: Int = 4 * Int(1+arc4random_uniform(256))
		let cols: Int = 4 * Int(1+arc4random_uniform(256))
		
		let LA: la_object_t = la_matrix_from_float_buffer((0..<rows*cols).map{(_)in Float(arc4random_uniform(256))/Float(128.0)-1.0}, la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		let LB: la_object_t = la_matrix_from_float_buffer((0..<cols).map{(_)in Float(arc4random_uniform(256))/Float(128.0)-1.0}, la_count_t(cols), la_count_t(1), la_count_t(1), NOHINT, ATTR)
		let LC: la_object_t = la_matrix_product(LA, LB)
		
		let MA: MTLBuffer = context.fromLAObject(LA)
		let MB: MTLBuffer = context.fromLAObject(LB)
		let MC: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows)
		
		let bs: Int = 64
		
		let group: MTLSize = MTLSize(width: rows/4, height: 1, depth: 1)
		let local: MTLSize = MTLSize(width: bs, height: 1, depth: 1)
		
		measureBlock {
			(0..<16).forEach {(_)in
				self.context.newComputeCommand(function: "gemv") {
					$0.setBuffer(MC, offset: 0, atIndex: 0)
					$0.setBuffer(MA, offset: 0, atIndex: 1)
					$0.setBuffer(MB, offset: 0, atIndex: 2)
					$0.setBytes([UInt32(rows/4), UInt32(cols/4)], length: 2*sizeof(UInt32), atIndex: 3)
					$0.setBytes([Float(1.0), Float(0.0)], length: 2*sizeof(Float), atIndex: 4)
					$0.setThreadgroupMemoryLength(sizeof(Float)*16*bs, atIndex: 0)
					$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
				}
			}
			self.context.join()
		}
		
		let CC: la_object_t = context.toLAObject(MC, rows: rows, cols: 1)
		context.join()
		
		let E: la_object_t = la_difference(LC, CC)
		let rmse: Float = la_norm_as_float(E, la_norm_t(LA_L2_NORM))
		XCTAssert(!isnan(rmse))
		XCTAssert(!isinf(rmse))
		if 1e-9 < rmse {
			XCTFail("RMSE: \(rmse)")
		}
	}
}