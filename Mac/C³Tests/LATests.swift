//
//  C_Tests.swift
//  C³Tests
//
//  Created by Kota Nakano on 6/6/16.
//
//
import Accelerate
import XCTest
@testable import C3

class LATests: XCTestCase {
	static let count: Int = 2 << 18
	static let original: [Float] = (0..<LATests.count).map { (_)in Float(arc4random_uniform(256)) - 128.0 }
	static let ideal: [Float] = LATests.original.map{Float( 0 < $0 ? 1 : 0 > $0 ? -1 : 0 )}
	func testDiv() {
		let x: Float = Float(arc4random())
		let y: Float = Float(arc4random())
		
		let X: la_object_t = la_splat_from_float(x, la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let Y: la_object_t = la_splat_from_float(y, la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		
		let Z: la_object_t = la_vector_from_splat(Y/X, 1)
		
		var z: Float = 0
		la_vector_to_float_buffer(&z, 1, Z)
		
		print("\(y/x) vs \(z)")
		XCTAssert((y/x-z)*(y/x-z)<1e-7)
	}
	func testDivs() {
		
		let rows: UInt = UInt(arc4random_uniform(1023)+1)
		let cols: UInt = UInt(arc4random_uniform(1023)+1)
		
		let count: Int = Int(rows*cols)
		
		let x: [Float] = (0..<count).map{(_)in Float(arc4random_uniform(256))+1.0}
		let y: [Float] = (0..<count).map{(_)in Float(arc4random_uniform(256))+1.0}
		
		let X: la_object_t = la_matrix_from_float_buffer(x, rows, cols, cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let Y: la_object_t = la_matrix_from_float_buffer(y, rows, cols, cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		
		let Z: la_object_t = Y / X
		XCTAssert( Z.rows == X.rows && Z.cols == X.cols )
		XCTAssert( Z.rows == Y.rows && Z.cols == Y.cols )
		
		let z: [Float] = [Float](count: count, repeatedValue: 0)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(z), cols, Z)
		
		(0..<z.count).forEach {
			XCTAssert((y[$0]/x[$0]-z[$0])*(y[$0]/x[$0]-z[$0])<1e-5)
		}
	}
	
	func testExp() {
		
		let rows: UInt = UInt(arc4random_uniform(1023)+1)
		let cols: UInt = UInt(arc4random_uniform(1023)+1)
		
		let count: Int = Int(rows*cols)
		
		let x: [Float] = (0..<count).map{(_)in Float(arc4random())/Float(UInt32.max)}
		let y: [Float] = x.map{exp($0)}
		
		let X: la_object_t = la_matrix_from_float_buffer(x, rows, cols, cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let Y: la_object_t = exp(X)
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(x), cols, Y)
		
		let e: [Float] = zip(x, y).map{$0.0-$0.1}
		let rmse: Float = sqrt(e.map{$0*$0}.reduce(0){$0+$1} / Float(count))
		
		XCTAssert( rmse < 1e-5 )

	}
	
	func testSQRT() {
		
		let rows: UInt = UInt(arc4random_uniform(1023)+1)
		let cols: UInt = UInt(arc4random_uniform(1023)+1)
		
		let count: Int = Int(rows*cols)
		
		let x: [Float] = (0..<count).map{(_)in Float(arc4random())/Float(UInt32.max)}
		let y: [Float] = x.map{sqrt($0)}
		
		let X: la_object_t = la_matrix_from_float_buffer(x, rows, cols, cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let Y: la_object_t = sqrt(X)
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(x), cols, Y)
		
		let e: [Float] = zip(x, y).map{$0.0-$0.1}
		let rmse: Float = sqrt(e.map{$0*$0}.reduce(0){$0+$1} / Float(count))
		
		XCTAssert( rmse < 1e-5 )
		
	}
	func testPdf() {
		
		let rows: UInt = UInt(arc4random_uniform(1023)+1)
		let cols: UInt = UInt(arc4random_uniform(1023)+1)
		
		let count: Int = Int(rows*cols)
		
		func p(let x: Float, let u: Float, let s: Float) -> Float {
			return exp(-0.5*(x-u)*(x-u)/s/s)/Float(sqrt(2.0*M_PI))/s
		}
		
		let x: [Float] = (0..<count).map{(_)in Float(arc4random())/Float(UInt32.max)}
		let u: [Float] = (0..<count).map{(_)in Float(arc4random())/Float(UInt32.max)}
		let s: [Float] = (0..<count).map{(_)in Float(arc4random())/Float(UInt32.max)}
		let y: [Float] = (0..<count).map{(let idx: Int)in p(x[idx], u: u[idx], s: s[idx])}
		
		let X: la_object_t = la_matrix_from_float_buffer(x, rows, cols, cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let U: la_object_t = la_matrix_from_float_buffer(u, rows, cols, cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let S: la_object_t = la_matrix_from_float_buffer(s, rows, cols, cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let Y: la_object_t = pdf(x: X, mu: U, sigma: S)
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(x), cols, Y)
		
		let e: [Float] = zip(x, y).map{$0.0-$0.1}
		let rmse: Float = sqrt(e.map{$0*$0}.reduce(0){$0+$1} / Float(count))
		
		XCTAssert( rmse < 1e-5 )
		
	}
	func testNormal() {
		
		let rows: UInt = UInt(arc4random_uniform(1023)+1)
		let cols: UInt = UInt(arc4random_uniform(1023)+1)
		
		let count: Int = Int(rows*cols)
		
		let N: la_object_t = normal(rows: rows, cols: cols)
		let buffer: [Float] = [Float](count: count, repeatedValue: 0)
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), cols, N)
		
		let m: Float = buffer.reduce(0){$0+$1}/Float(count)
		let v: Float = buffer.map{($0-m)*($0-m)}.reduce(0){$0+$1}/Float(count)
		let s: Float = sqrt(v)
		
		print(m, s)
	}
	func testStep() {
		let rows: UInt = 4
		let cols: UInt = 4
		
		let count: Int = Int(rows*cols)
		
		let N: la_object_t = 4 + 4 * normal(rows: rows, cols: cols)
		let buffer0: [Float] = [Float](count: count, repeatedValue: 0)
		let buffer1: [Float] = [Float](count: count, repeatedValue: 0)
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer0), cols, N)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer1), cols, step(N))
		
		(0..<count).forEach {
			XCTAssert(( 0 < buffer0[$0] ? 1 : 0 ) == buffer1[$0])
		}
	}
	func testSign() {
		let rows: UInt = 4
		let cols: UInt = 4
		
		let count: Int = Int(rows*cols)
		
		let N: la_object_t = 4 + 4 * normal(rows: rows, cols: cols)
		let buffer0: [Float] = [Float](count: count, repeatedValue: 0)
		let buffer1: [Float] = [Float](count: count, repeatedValue: 0)
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer0), cols, N)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer1), cols, sign(N))
		
		(0..<count).forEach {
			XCTAssert(( 0 < buffer0[$0] ? 1 : 0 > buffer0[$0] ? -1 : 0 ) == buffer1[$0])
		}
	}
	func testSignRaw() {
		let res: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(LATests.count)
		let data: NSData = NSData(bytes: LATests.original, length: sizeof(Float)*LATests.original.count)
		data.getBytes(res, length: sizeof(Float)*LATests.count)
		measureBlock {
			(0..<LATests.count).forEach {
				let mem: Float = res.advancedBy($0).memory
				res.advancedBy($0).memory = 0 < mem ? 1 : 0 > mem ? -1 : 0
			}
		}
		(0..<LATests.count).forEach {
			let a: Float = res.advancedBy($0).memory
			let b: Float = LATests.ideal[$0]
			XCTAssert(a==b)
		}
		res.dealloc(LATests.count)
	}
	func testSignThrcs() {
		let ref: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(LATests.count)
		let data: NSData = NSData(bytes: LATests.original, length: sizeof(Float)*LATests.original.count)
		data.getBytes(ref, length: sizeof(Float)*LATests.count)
		measureBlock {
			let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(LATests.count)
			vDSP_vthrsc(ref, 1, [Float(0.0)], [Float(0.5)], cache, 1, vDSP_Length(LATests.count))
			vDSP_vneg(ref, 1, ref, 1, vDSP_Length(LATests.count))
			vDSP_vthrsc(ref, 1, [Float(0.0)], [-Float(0.5)], ref, 1, vDSP_Length(LATests.count))
			vDSP_vadd(cache, 1, ref, 1, ref, 1, vDSP_Length(LATests.count))
			cache.dealloc(LATests.count)
		}
		(0..<LATests.count).forEach {
			let a: Float = ref.advancedBy($0).memory
			let b: Float = LATests.ideal[$0]
			XCTAssert(a==b)
		}
		ref.dealloc(LATests.count)
	}
	func testSignLim() {
		let ref: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(LATests.count)
		let data: NSData = NSData(bytes: LATests.original, length: sizeof(Float)*LATests.original.count)
		data.getBytes(ref, length: sizeof(Float)*LATests.count)
		measureBlock {
			let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(LATests.count)
			vDSP_vlim(ref, 1, [Float(0.0)], [Float(0.5)], cache, 1, vDSP_Length(LATests.count))
			vDSP_vneg(ref, 1, ref, 1, vDSP_Length(LATests.count))
			vDSP_vlim(ref, 1, [Float(0.0)], [-Float(0.5)], ref, 1, vDSP_Length(LATests.count))
			vDSP_vadd(cache, 1, ref, 1, ref, 1, vDSP_Length(LATests.count))
			cache.dealloc(LATests.count)
		}
		(0..<LATests.count).forEach {
			let a: Float = ref.advancedBy($0).memory
			let b: Float = LATests.ideal[$0]
			XCTAssert(a==b)
		}
		ref.dealloc(LATests.count)
	}
/*
	func testSignSpd() {
		let len: Int = 1024
		let org: [Float] = (0..<len).map{(_)in Float(arc4random_uniform(256))-128.0}
		let idl: [Float] = org.map{Float( 0 < $0 ? 1 : 0 > $0 ? -1 : 0 )}
		
		var ref: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(len)
		var fer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(len)
		var res: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(len)
		
		NSData(bytes: org, length: sizeof(Float)*org.count).getBytes(ref, length: sizeof(Float)*len)
		
		NSData(bytes: org, length: sizeof(Float)*org.count).getBytes(ref, length: sizeof(Float)*len)
		measureBlock {
			let result: [Float] = [Float](count: len, repeatedValue: 0)
			vDSP_vlim(ref, 1, [Float(0.0)], [Float(0.5)], fer, 1, vDSP_Length(len))
			vDSP_vneg(ref, 1, ref, 1, vDSP_Length(len))
		}
		
		
		fer.dealloc(len)
		ref.dealloc(len)
		res.dealloc(len)
		
	}
*/
}