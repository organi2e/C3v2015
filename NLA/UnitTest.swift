//
//  NLATests.swift
//  NLATests
//
//  Created by Kota Nakano on 7/20/16.
//
//
import Accelerate
import XCTest
@testable import NLA

class UnitTests: XCTestCase {
	
	func testPDF () {
		guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
			XCTFail("no device found")
			return
		}
		guard let unit: Unit = try? Unit(device: device) else {
			XCTFail("no unit created")
			return
		}
		let rows: la_count_t = la_count_t(arc4random_uniform(240)*0+4)
		let cols: la_count_t = la_count_t(arc4random_uniform(240)*0+4)
		let count: Int = Int(rows*cols)
		let group: dispatch_group_t = dispatch_group_create()
		let x: la_object_t = unit.normal(rows: Int(rows), cols: Int(cols), group: group)
		let u: la_object_t = la_splat_from_float(0, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
		let s: la_object_t = la_splat_from_float(1, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
		let n: la_object_t = unit.pdf(x: x, mu: u, sigma: s, waits: [group])
		let v: [Float] = [Float](count: count, repeatedValue: 0)
		
		unit.join()
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(v), cols, x)
		
		let d: [Float] = v.map { expf(-($0*$0)/2.0)/sqrtf(Float(2.0*M_PI)) }
		let y: [Float] = v.map { 0.0 * $0 }
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(y), cols, n)
		let e: Float = rmse(d: d, y: y)
		print(d)
		print(y)
		if 1e-5 < e || isnan(e) || isinf(e) {
			XCTFail()
		} else {
			print("RMSE: \(e)")
		}
	}
	func testCDF () {
		guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
			XCTFail("no device found")
			return
		}
		guard let unit: Unit = try? Unit(device: device) else {
			XCTFail("no unit created")
			return
		}
		let rows: la_count_t = la_count_t(arc4random_uniform(240)*4+64)
		let cols: la_count_t = la_count_t(arc4random_uniform(240)*4+64)
		let count: Int = Int(rows*cols)
		let group: dispatch_group_t = dispatch_group_create()
		let x: la_object_t = unit.normal(rows: Int(rows), cols: Int(cols), group: group)
		let u: la_object_t = la_splat_from_float(0, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
		let s: la_object_t = la_splat_from_float(1, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
		let n: la_object_t = unit.cdf(x: x, mu: u, sigma: s, waits: [group])
		let v: [Float] = [Float](count: count, repeatedValue: 0)
		
		unit.join()
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(v), cols, x)
		
		let d: [Float] = v.map { 0.5 * erfcf ( -$0 / sqrt(2.0) ) }
		let y: [Float] = v.map { 0.0 * $0 }
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(y), cols, n)
		let e: Float = rmse(d: d, y: y)
		if 1e-3 < e || isnan(e) || isinf(e) {
			XCTFail()
		} else {
			print("RMSE: \(e)")
		}
	}
	/*
	func testSigmoid() {
		do {
			guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
				XCTFail("no device found")
				return
			}
			let unit: Unit = try Unit(device: device)
			let x: la_object_t = la_matrix_from_float_buffer(Array<Float>([-4.0,-2.0, 0.0, 2.0]), la_count_t(2), la_count_t(2), la_count_t(2), Unit.hint, Unit.attr)
			let y: la_object_t = unit.sigmoid(x)
			unit.join()
			let v: [Float] = [0,0,0,0]
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(v), la_count_t(2), y)
			print(v)
		} catch {
			XCTFail("no unit created")
		}
	}
	*/
	func testNormal() {
		guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
			XCTFail("no device found")
			return
		}
		guard let unit: Unit = try? Unit(device: device) else {
			XCTFail("no unit created")
			return
		}

		let U: Float = Float(arc4random_uniform(UInt32(1024)))
		let S: Float = Float(arc4random_uniform(UInt32(1024))+1)
		let rows: la_count_t = la_count_t(arc4random_uniform(UInt32(240))*4+64)
		let cols: la_count_t = la_count_t(arc4random_uniform(UInt32(240))*4+64)
		let count: Int = Int(rows*cols)
		
		let mu: la_object_t = la_matrix_from_splat(la_splat_from_float(U, Unit.attr), rows, cols)
		let sigma: la_object_t = la_matrix_from_splat(la_splat_from_float(S, Unit.attr), rows, cols)
		
		let group: dispatch_group_t = dispatch_group_create()
		let values: [Float] = [Float](count: count, repeatedValue: 0)
		
		let normal: la_object_t = unit.normal(rows: Int(rows), cols: Int(cols), group: group)
		let gauss: la_object_t = la_sum(mu, la_elementwise_product(sigma, normal))
		
		group.wait()
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(values), cols, gauss)
		
		let u: Float = values.reduce(0){$0+$1}/Float(count)
		let s: Float = sqrtf(values.map{$0-u}.map{$0*$0}.reduce(0){$0+$1}/Float(count))
		
		if abs(log(u/U)) > 0.03 || abs(log(s/S)) > 0.03 {
			XCTFail("U: \(u)/\(U), S: \(s)/\(S)")
		} else {
			print("U: \(u)/\(U), S: \(s)/\(S)")
		}
	}
	func rmse ( let d d: [Float], let y: [Float] ) -> Float {
		XCTAssert(d.count==y.count)
		return sqrt((zip(d, y).map{$0.0-$0.1}.map{$0*$0}.reduce(0){$0+$1})/Float(d.count))
	}
}
