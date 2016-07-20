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
	func testNormal() {
		guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
			XCTFail("no device found")
			return
		}
		guard let unit: Unit = try? Unit(device: device) else {
			XCTFail("no unit created")
			return
		}
		let rows: Int = 256
		let cols: Int = 256
		let U: la_object_t = la_splat_from_float(500.0, Unit.attr)
		let S: la_object_t = la_splat_from_float(100.0, Unit.attr)
		let mu: la_object_t = la_matrix_from_splat(U, la_count_t(rows), la_count_t(cols))
		let sigma: la_object_t = la_matrix_from_splat(S, la_count_t(rows), la_count_t(cols))
		let group: dispatch_group_t = dispatch_group_create()
		let N: la_object_t = unit.normal(mu: mu, sigma: sigma, group: group)
		let values: [Float] = [Float](count: rows*cols, repeatedValue: 0)
//		dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
		unit.join()
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(values), la_count_t(cols), N)
		let m: Float = values.reduce(0){$0+$1}/Float(rows*cols)
		let s: Float = sqrtf(values.map{($0-m)*($0-m)}.reduce(0){$0+$1}/Float(rows*cols))
		
//		print(values)
		print(m, s)
		
	}
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
}
