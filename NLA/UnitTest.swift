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
	func testSigmoid() {
		do {
			guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
				XCTFail("no device found")
				return
			}
			let unit: Unit = try Unit(device: device)
			let x: la_object_t = la_matrix_from_float_buffer(Array<Float>([-1.0, 0.0, 1.0, 2.0]), la_count_t(2), la_count_t(2), la_count_t(2), Unit.hint, Unit.attr)
			let y: la_object_t = unit.sigmoid(x).0
			unit.join()
			let v: [Float] = [0,0,0,0]
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(v), la_count_t(2), y)
			print(v)
		} catch {
			XCTFail("no unit created")
		}
	}
}
