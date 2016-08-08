//
//  BlobTests.swift
//  Mac
//
//  Created by Kota Nakano on 7/23/16.
//
//
import Accelerate
import XCTest
@testable import C3

class GaussTests: XCTestCase {
	let NOHINT: la_hint_t = la_hint_t(LA_NO_HINT)
	let ATTR: la_attribute_t = la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)
	func testRefresh() {
		guard let context: Context = try?Context() else {
			XCTFail()
			return
		}
		guard let gauss: Gauss = context.new() else {
			XCTFail()
			return
		}
		let dmean: Float = Float(arc4random())/Float(UInt16.max)
		let dvariance: Float = Float(arc4random())/Float(UInt16.max)
		let rows: UInt = 64
		let cols: UInt = 64
		let count: Int = Int(rows*cols)
		
		gauss.resize(rows: Int(rows), cols: Int(cols))
		gauss.adjust(mean: dmean, variance: dvariance)
		gauss.refresh()
		
		context.join()
		
		var ymean: Float = 0.0
		var ydeviation: Float = 0.0
		
		let cache: [Float] = [Float](count: count, repeatedValue: 0.0)
		
		vDSP_meanv(UnsafePointer<Float>(gauss.value.contents()), 1, &ymean, vDSP_Length(count))
		vDSP_vsadd(UnsafePointer<Float>(gauss.value.contents()), 1, [-ymean], UnsafeMutablePointer<Float>(cache), 1, vDSP_Length(count))
		vDSP_rmsqv(UnsafePointer<Float>(cache), 1, &ydeviation, vDSP_Length(count))
		
		XCTAssert(abs(log(ymean)-log(dmean))<0.1)
		XCTAssert(abs(2.0*log(ydeviation)-log(dvariance))<0.1)
		
	}
}
