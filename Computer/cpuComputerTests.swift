//
//  cpuComputerTests.swift
//  ComputerTests
//
//  Created by Kota Nakano on 7/18/16.
//
//

import Accelerate
import XCTest
@testable import Computer

class cpuComputerTests: XCTestCase {
	/*
	func testLA() {
		let M: Int = 1024
		let K: Int = 1024
		let N: Int = 1024
		
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*M*N)
		let a: Buffer = computer.newBuffer(length: sizeof(Float)*M*K)
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*K*N)
		
		for col in 0..<M {
			for row in 0..<K {
				a.scalar[col*K+row] = Float(arc4random())/Float(UInt32.max)
			}
		}
		
		for col in 0..<K {
			for row in 0..<N {
				x.scalar[col*N+row] = Float(arc4random())/Float(UInt32.max)
			}
		}
		
		let X: la_object_t = la_matrix_from_float_buffer_nocopy(x.scalar.baseAddress, la_count_t(N), la_count_t(K), la_count_t(K), la_hint_t(LA_NO_HINT), nil, la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let A: la_object_t = la_matrix_from_float_buffer_nocopy(a.scalar.baseAddress, la_count_t(K), la_count_t(N), la_count_t(N), la_hint_t(LA_NO_HINT), nil, la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		
		measureBlock {
			la_matrix_to_float_buffer(y.scalar.baseAddress, la_count_t(N), la_matrix_product(A, X))
			la_matrix_to_float_buffer(y.scalar.baseAddress, la_count_t(N), la_matrix_product(A, X))
			la_matrix_to_float_buffer(y.scalar.baseAddress, la_count_t(N), la_matrix_product(A, X))
			la_matrix_to_float_buffer(y.scalar.baseAddress, la_count_t(N), la_matrix_product(A, X))
			la_matrix_to_float_buffer(y.scalar.baseAddress, la_count_t(N), la_matrix_product(A, X))
			la_matrix_to_float_buffer(y.scalar.baseAddress, la_count_t(N), la_matrix_product(A, X))
			la_matrix_to_float_buffer(y.scalar.baseAddress, la_count_t(N), la_matrix_product(A, X))
			la_matrix_to_float_buffer(y.scalar.baseAddress, la_count_t(N), la_matrix_product(A, X))
			la_matrix_to_float_buffer(y.scalar.baseAddress, la_count_t(N), la_matrix_product(A, X))
			la_matrix_to_float_buffer(y.scalar.baseAddress, la_count_t(N), la_matrix_product(A, X))
		}
		
	}
*/
	/*
	func testBlas() {
		let M: Int = 24
		let K: Int = 24
		let N: Int = 24
		
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*M*N)
		let a: Buffer = computer.newBuffer(length: sizeof(Float)*M*K)
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*K*N)
		
		for col in 0..<M {
			for row in 0..<K {
				a.scalar[col*K+row] = Float(arc4random())/Float(UInt32.max)
			}
		}
		
		for col in 0..<K {
			for row in 0..<N {
				x.scalar[col*N+row] = Float(arc4random())/Float(UInt32.max)
			}
		}
		
		measureBlock {
			cblas_sgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, Int32(M), Int32(N), Int32(K), 1.0, a.scalar.baseAddress, Int32(K), x.scalar.baseAddress, Int32(N), 0.0, y.scalar.baseAddress, Int32(N))
			cblas_sgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, Int32(M), Int32(N), Int32(K), 1.0, a.scalar.baseAddress, Int32(K), x.scalar.baseAddress, Int32(N), 0.0, y.scalar.baseAddress, Int32(N))
			cblas_sgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, Int32(M), Int32(N), Int32(K), 1.0, a.scalar.baseAddress, Int32(K), x.scalar.baseAddress, Int32(N), 0.0, y.scalar.baseAddress, Int32(N))
			cblas_sgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, Int32(M), Int32(N), Int32(K), 1.0, a.scalar.baseAddress, Int32(K), x.scalar.baseAddress, Int32(N), 0.0, y.scalar.baseAddress, Int32(N))
			cblas_sgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, Int32(M), Int32(N), Int32(K), 1.0, a.scalar.baseAddress, Int32(K), x.scalar.baseAddress, Int32(N), 0.0, y.scalar.baseAddress, Int32(N))
			cblas_sgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, Int32(M), Int32(N), Int32(K), 1.0, a.scalar.baseAddress, Int32(K), x.scalar.baseAddress, Int32(N), 0.0, y.scalar.baseAddress, Int32(N))
			cblas_sgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, Int32(M), Int32(N), Int32(K), 1.0, a.scalar.baseAddress, Int32(K), x.scalar.baseAddress, Int32(N), 0.0, y.scalar.baseAddress, Int32(N))
			cblas_sgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, Int32(M), Int32(N), Int32(K), 1.0, a.scalar.baseAddress, Int32(K), x.scalar.baseAddress, Int32(N), 0.0, y.scalar.baseAddress, Int32(N))
			cblas_sgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, Int32(M), Int32(N), Int32(K), 1.0, a.scalar.baseAddress, Int32(K), x.scalar.baseAddress, Int32(N), 0.0, y.scalar.baseAddress, Int32(N))
			cblas_sgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, Int32(M), Int32(N), Int32(K), 1.0, a.scalar.baseAddress, Int32(K), x.scalar.baseAddress, Int32(N), 0.0, y.scalar.baseAddress, Int32(N))
		}
	}
	*/
	func testGEMV() {
		let M: Int = 4000
		let N: Int = 1000
		
		let d: Buffer = computer.newBuffer(length: sizeof(Float)*M)
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*M)
		let a: Buffer = computer.newBuffer(length: sizeof(Float)*M*N)
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*N)
		
		for col in 0..<M {
			for row in 0..<N {
				a.scalar[row*M+col] = Float(arc4random())/Float(UInt32.max)
			}
		}
		for row in 0..<N {
			x.scalar[row] = Float(arc4random())/Float(UInt32.max)
		}
		
		measureBlock {
			self.computer.gemv(y, a: a, x: x, alpha: 1.0, beta: 0.0, transpose: false, sync: false)
			self.computer.gemv(y, a: a, x: x, alpha: 1.0, beta: 0.0, transpose: false, sync: false)
			self.computer.gemv(y, a: a, x: x, alpha: 1.0, beta: 0.0, transpose: false, sync: false)
			self.computer.gemv(y, a: a, x: x, alpha: 1.0, beta: 0.0, transpose: false, sync: false)
			self.computer.gemv(y, a: a, x: x, alpha: 1.0, beta: 0.0, transpose: false, sync: false)
			self.computer.gemv(y, a: a, x: x, alpha: 1.0, beta: 0.0, transpose: false, sync: false)
			self.computer.gemv(y, a: a, x: x, alpha: 1.0, beta: 0.0, transpose: false, sync: false)
			self.computer.gemv(y, a: a, x: x, alpha: 1.0, beta: 0.0, transpose: false, sync: false)
			self.computer.gemv(y, a: a, x: x, alpha: 1.0, beta: 0.0, transpose: false, sync: false)
			self.computer.gemv(y, a: a, x: x, alpha: 1.0, beta: 0.0, transpose: false, sync: false)
			self.computer.join()
		}
		
		let A: la_object_t = la_matrix_from_float_buffer_nocopy(a.scalar.baseAddress, la_count_t(M), la_count_t(N), la_count_t(N), la_hint_t(LA_NO_HINT), nil, la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let X: la_object_t = la_matrix_from_float_buffer_nocopy(x.scalar.baseAddress, la_count_t(N), la_count_t(1), la_count_t(1), la_hint_t(LA_NO_HINT), nil, la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		la_matrix_to_float_buffer(d.scalar.baseAddress, la_count_t(1), la_matrix_product(A, X))

		let e = rmse(d: d, y: y)
		if 1e-3 < e {
			print("D: \(Array(d.scalar))")
			print("Y: \(Array(y.scalar))")
			XCTFail("RMSE: \(e)")
		}
	}
	func testGEMM() {
		let M: Int = 1024
		let K: Int = 1024
		let N: Int = 1024
		
		let d: Buffer = computer.newBuffer(length: sizeof(Float)*M*N)
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*M*N)
		let a: Buffer = computer.newBuffer(length: sizeof(Float)*M*K)
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*K*N)
		
		for col in 0..<M {
			for row in 0..<K {
				a.scalar[row*M+col] = Float(arc4random())/Float(UInt32.max)
			}
		}
		
		for col in 0..<K {
			for row in 0..<N {
				x.scalar[row*K+col] = Float(arc4random())/Float(UInt32.max)
			}
		}
		computer.clear(d, sync: false)
		computer.clear(y, sync: false)
		
		measureBlock {
			self.computer.gemm(y, a: a, x: x, alpha: 1.0, beta: 0.0, dim: (M, K, N), transpose: (false, false), sync: false)
			self.computer.gemm(y, a: a, x: x, alpha: 1.0, beta: 0.0, dim: (M, K, N), transpose: (false, false), sync: false)
			self.computer.gemm(y, a: a, x: x, alpha: 1.0, beta: 0.0, dim: (M, K, N), transpose: (false, false), sync: false)
			self.computer.gemm(y, a: a, x: x, alpha: 1.0, beta: 0.0, dim: (M, K, N), transpose: (false, false), sync: false)
			self.computer.gemm(y, a: a, x: x, alpha: 1.0, beta: 0.0, dim: (M, K, N), transpose: (false, false), sync: false)
			self.computer.gemm(y, a: a, x: x, alpha: 1.0, beta: 0.0, dim: (M, K, N), transpose: (false, false), sync: false)
			self.computer.gemm(y, a: a, x: x, alpha: 1.0, beta: 0.0, dim: (M, K, N), transpose: (false, false), sync: false)
			self.computer.gemm(y, a: a, x: x, alpha: 1.0, beta: 0.0, dim: (M, K, N), transpose: (false, false), sync: false)
			self.computer.gemm(y, a: a, x: x, alpha: 1.0, beta: 0.0, dim: (M, K, N), transpose: (false, false), sync: false)
			self.computer.gemm(y, a: a, x: x, alpha: 1.0, beta: 0.0, dim: (M, K, N), transpose: (false, false), sync: false)
			self.computer.gemm(y, a: a, x: x, alpha: 1.0, beta: 0.0, dim: (M, K, N), transpose: (false, false), sync: false)
			self.computer.gemm(y, a: a, x: x, alpha: 1.0, beta: 0.0, dim: (M, K, N), transpose: (false, false), sync: false)
			self.computer.join()
		}
		self.computer.join()
		let A: la_object_t = la_matrix_from_float_buffer_nocopy(a.scalar.baseAddress, la_count_t(M), la_count_t(K), la_count_t(K), la_hint_t(LA_NO_HINT), nil, la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let X: la_object_t = la_matrix_from_float_buffer_nocopy(x.scalar.baseAddress, la_count_t(K), la_count_t(N), la_count_t(N), la_hint_t(LA_NO_HINT), nil, la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		la_matrix_to_float_buffer(d.scalar.baseAddress, la_count_t(N), la_matrix_product(A, X))
		let e = rmse(d: d, y: y)
		if 1e-3 < e {
			print("D: \(Array(d.scalar)[0..<16])")
			print("Y: \(Array(y.scalar)[0..<16])")
			XCTFail("RMSE: \(e)")
		}
		
	}
	/*
	func testSQ() {
		let n: Int = 1 << order
		
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let d: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		
		(0..<n).forEach {
			x.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			d.scalar[$0] = x.scalar[$0] * x.scalar[$0]
		}
		
		measureBlock {
			self.computer.sq(y, x, sync: false)
			self.computer.join()
		}
		
		if 1e-5 < rmse(d: d, y: y) {
			if n < 64 {
				print(Array(d.scalar))
				print(Array(y.scalar))
			}
			XCTFail()
		}
	}
	func testSQRT() {
		let n: Int = 1 << order
		
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let d: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		
		(0..<n).forEach {
			x.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			d.scalar[$0] = Float(sqrt(Double(x.scalar[$0])))
		}
		
		measureBlock {
			self.computer.sqrt(y, x, sync: false)
			self.computer.join()
		}
		
		if 1e-5 < rmse(d: d, y: y) {
			if n < 64 {
				print(Array(d.scalar))
				print(Array(y.scalar))
			}
			XCTFail()
		}
	}
	func testEXP() {
		let n: Int = 1 << order
		
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let d: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		
		(0..<n).forEach {
			x.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			d.scalar[$0] = Float(exp(Double(x.scalar[$0])))
		}
		
		measureBlock {
			self.computer.exp(y, x, sync: false)
			self.computer.join()
		}
		
		if 1e-5 < rmse(d: d, y: y) {
			if n < 64 {
				print(Array(d.scalar))
				print(Array(y.scalar))
			}
			XCTFail()
		}
	}
	func testPDF() {
		let n: Int = 1 << order
		
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let u: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let s: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let d: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		
		(0..<n).forEach {
			x.scalar[$0] = Float($0 - n/2)/Float(n)
			u.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			s.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			
			let lambda: Double = (Double(x.scalar[$0]) - Double(u.scalar[$0]))/Double(s.scalar[$0])
			d.scalar[$0] = Float(exp(-0.5*lambda*lambda)/Double(s.scalar[$0])/sqrt(2.0*M_PI))
		}
		
		measureBlock {
			self.computer.pdf(y, x: x, u: u, s: s, sync: false)
			self.computer.join()
		}
		
		if 1e-5 < rmse(d: d, y: y) {
			if n < 64 {
				print(Array(d.scalar))
				print(Array(y.scalar))
			}
			XCTFail()
		}
	}
	func testCDF() {
		let n: Int = 1 << order
		
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let u: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let s: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let d: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		
		(0..<n).forEach {
			x.scalar[$0] = Float($0 - n/2)/Float(n)
			u.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			s.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			
			let lambda: Double = (Double(x.scalar[$0]) - Double(u.scalar[$0]))/Double(s.scalar[$0])*M_SQRT1_2
			d.scalar[$0] = Float(0.5*erfc(-lambda))
		}
		
		measureBlock {
			self.computer.cdf(y, x: x, u: u, s: s, sync: false)
			self.computer.join()
		}
		
		if 1e-5 < rmse(d: d, y: y) {
			if n < 64 {
				print(Array(d.scalar))
				print(Array(y.scalar))
			}
			XCTFail()
		}
	}
	func testSigmoid() {
		let n: Int = 1 << order
		
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let u: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let s: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let d: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		
		(0..<n).forEach {
			x.scalar[$0] = Float(M_PI) * Float($0 - n/2)/Float(n)
			u.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			s.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			d.scalar[$0] = 0.5 + 0.5 * tanhf((x.scalar[$0]-u.scalar[$0])/(s.scalar[$0]))
		}
		
		measureBlock {
			self.computer.sigmoid(y, x: x, u: u, s: s, sync: false)
			self.computer.join()
		}
		if 1e-5 < rmse(d: d, y: y) {
			if n < 64 {
				print(Array(d.scalar))
				print(Array(y.scalar))
			}
			XCTFail()
		}
	}
	func testNormal() {
		let n: Int = 1 << order
		let M: Float = 500
		let S: Float = 100
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let u: Buffer = computer.newBuffer(data: NSData(bytes: [Float](count: n, repeatedValue: M), length: sizeof(Float)*n))
		let s: Buffer = computer.newBuffer(data: NSData(bytes: [Float](count: n, repeatedValue: S), length: sizeof(Float)*n))
		
		measureBlock {
			self.computer.normal(y, u: u, s: s, sync: false)
			self.computer.join()
		}
		
		let mu: Float = y.scalar.reduce(0){$0+$1}/Float(n)
		let sigma: Float = sqrtf(y.scalar.map{($0-mu)*($0-mu)}.reduce(0){$0+$1}/Float(n))
		
		if 1.0 < abs(M-mu) || 3.0 < abs(S-sigma) {
			print(mu, sigma)
			XCTFail()
		}
	}
*/
	lazy var computer: Computer = self.implementation()
	let order: Int = 24
	func rmse(let d d: Buffer, let y: Buffer) -> Float {
		assert(d.scalar.count==y.scalar.count)
		let df: [Float] = zip(d.scalar, y.scalar).map{$0.0-$0.1}
		let sd: [Float] = df.map{$0*$0}
		let rme: Float = sd.reduce(0){$0+$1}/Float(d.scalar.count)
		return sqrtf(rme)
	}
	func implementation() -> Computer {
		return cpuComputer()
	}
}
