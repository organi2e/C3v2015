//
//  ComputerTests.swift
//  Mac
//
//  Created by Kota Nakano on 6/7/16.
//
//
import Accelerate
import XCTest
@testable import C3

class EdgeTests: XCTestCase {
	let context: Context = try!Context()
	func dump(let buffer: MTLBuffer, let rows: Int, let cols: Int) {
		let matrix: la_object_t = context.toLAObject(buffer, rows: rows, cols: cols)
		let cache: [Float] = [Float](count: rows*cols, repeatedValue: 0.0)
		context.join()
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(cols), matrix)
		(0..<rows).forEach {
			print(cache[$0*cols..<$0*cols+cols])
		}
	}
	func testCollect() {
		
		let rows: Int = 8
		let cols: Int = 8
		
		let input: Cell = try!context.newCell(width: rows)
		let output: Cell = try!context.newCell(width: cols)
		
		guard let edge: Edge = context.new() else {
			XCTFail()
			return
		}
		edge.resize(rows: rows, cols: cols)
		edge.adjust(mean: 0.0, variance: 1/Float(cols))
		edge.input = input
		edge.output = output
		edge.setup()
		
		context.join()
		try!context.save()
		
		input.oClear()
		output.iClear()
		
		context.join()
		
		let value: MTLBuffer = context.newBuffer([Float](count: rows, repeatedValue: 0.0))
		let mean: MTLBuffer = context.newBuffer([Float](count: rows, repeatedValue: 0.0))
		let variance: MTLBuffer = context.newBuffer([Float](count: rows, repeatedValue: 0.0))
		
		input.active = [false, false, false, false, false, false, true, false];
		edge.collect(value: value, mean: mean, variance: variance, visit: [])
		
		dump(value, rows: rows, cols: 1)
		
		
	}
	func testRefresh() {
		guard let edge: Edge = context.new() else {
			XCTFail()
			return
		}
		let dmean: Float = Float(arc4random())/Float(UInt16.max)
		let dvariance: Float = Float(arc4random())/Float(UInt16.max)
		let rows: Int = 64
		let cols: Int = 64
		let count: Int = Int(rows*cols)
		
		edge.resize(rows: rows, cols: cols)
		edge.adjust(mean: dmean, variance: dvariance)
		edge.refresh()
		
		let value: la_object_t = context.toLAObject(edge.value, rows: count, cols: 1)
		
		var ymean: Float = 0.0
		var ydeviation: Float = 0.0
		
		let cache: [Float] = [Float](count: count, repeatedValue: 0.0)
		
		context.join()
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), 1, value)
		
		vDSP_meanv(UnsafePointer<Float>(cache), 1, &ymean, vDSP_Length(count))
		XCTAssert(!isnan(ymean))
		XCTAssert(!isinf(ymean))
		
		if 1e-1 < abs(log(ymean)-log(dmean)) {
			XCTFail("\(ymean) vs \(dmean)")
		}
		
		vDSP_vsadd(UnsafePointer<Float>(cache), 1, [-ymean], UnsafeMutablePointer<Float>(cache), 1, vDSP_Length(count))
		vDSP_rmsqv(UnsafePointer<Float>(cache), 1, &ydeviation, vDSP_Length(count))
		XCTAssert(!isnan(ydeviation))
		XCTAssert(!isinf(ydeviation))
		
		if 1e-1 < abs(2.0*log(ydeviation)-log(dvariance)) {
			XCTFail("\(ydeviation*ydeviation) vs \(dvariance)")
		}
		
	}
}

