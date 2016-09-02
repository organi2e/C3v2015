//
//  ArtTests.swift
//  Mac
//
//  Created by Kota Nakano on 8/23/16.
//
//
/*
import Accelerate
import XCTest
import simd
@testable import C3

class ArtTests: XCTestCase {
	let context: Context = try!Context()
	
	let rows: Int = 1024
	let cols: Int = 1024
	
	func testCPURC4Uniform() {
		let buffer: [UInt32] = [UInt32](count: rows*cols, repeatedValue: 0)
		let array: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		measureBlock {
			(0..<64).forEach {(_)in
				arc4random_buf(UnsafeMutablePointer<Void>(buffer), sizeof(UInt32)*self.rows*self.cols)
				vDSP_vfltu32(buffer, 1, UnsafeMutablePointer<Float>(array), 1, vDSP_Length(self.rows*self.cols))
				vDSP_vsmul(array, 1, [Float(1.0/4294967296.0)], UnsafeMutablePointer<Float>(array), 1, vDSP_Length(self.rows*self.cols))
			}
		}
		
		let mean: Float = array.reduce(0) { $0.0 + $0.1 } / Float(rows*cols)
		let max_: Float = array.reduce(-1) { max($0.0, $0.1) }
		let min_: Float = array.reduce( 2) { min($0.0, $0.1) }
		print(min_, max_, mean)

		let fp = fopen("/tmp/rc4.raw", "wb")
		fwrite(array, sizeof(Double), rows*cols, fp)
		fclose(fp)
		
	}
	func testMTLEXSUniform() {
		
		let buffer: MTLBuffer = context.newBuffer(length: sizeof(UInt32)*rows*cols)
		
		measureBlock {
			(0..<64).forEach {(_)in
				Art.uniform(context: self.context, χ: buffer, bs: 64)
			}
			self.context.join()
		}
		
		let ref: UnsafeBufferPointer<Float> = UnsafeBufferPointer<Float>(start: UnsafePointer<Float>(buffer.contents()), count: rows*cols)
		
		let array: [Float] = Array<Float>(ref)
		let mean: Float = array.reduce(0) { $0.0 + $0.1 } / Float(rows*cols)
		let max_: Float = array.reduce(-1) { max($0.0, $0.1) }
		let min_: Float = array.reduce( 2) { min($0.0, $0.1) }
		print(min_, max_, mean)
		
		let fp = fopen("/tmp/xor.raw", "wb")
		fwrite(array, sizeof(Double), rows*cols, fp)
		fclose(fp)
	}
}
*/