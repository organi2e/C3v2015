//
//  ComputerTests.swift
//  Mac
//
//  Created by Kota Nakano on 6/7/16.
//
//

import Foundation
import simd
import XCTest
@testable import C3

class ComputerTests: XCTestCase {
	func testGEMV() {
		do {
			let cpucomputer: Computer = try Computer()
			let gpucomputer: Computer = try Computer(device: MTLCreateSystemDefaultDevice())
			
			XCTAssert(gpucomputer.poweredbygpu)
			
			[cpucomputer, gpucomputer].forEach {
				let m: Int = 4
				let n: Int = 4 * Int(arc4random_uniform(UInt32(16))) + 4
				let x: Buffer = $0.newBuffer(length: sizeof(Float)*n)
				let y: Buffer = $0.newBuffer(length: sizeof(Float)*m)
				let a: Buffer = $0.newBuffer(length: sizeof(Float)*m*n)
				
				(0..<n).forEach {
					x.scalar[$0] = Float(arc4random_uniform(UInt32(256)))
				}
				(0..<n*m).forEach {
					a.scalar[$0] = Float(arc4random_uniform(UInt32(256)))
				}
				
				let z: float4 = zip(a.matrix, x.vector).map{$0*$1}.reduce(float4(0)){$0.0+$0.1}
				$0.gemv(y: y, beta: 0, a: a, x: x, alpha: 1, n: n, m: m, trans: false)
				$0.join()
				
				print("GPU: \($0.poweredbygpu), \(z) vs \(y.vector[0])")
				XCTAssert( z == y.vector[0] )
				
				//let w: float4 = a.matrix[0] * x.vector[0] + a.matrix[1] * x.vector[1]
				
			}
		} catch let e {
			print(e)
			XCTFail()
		}
	}
}
func == (let a: float4, let b: float4) -> Bool {
	return
		a.x == b.x &&
			a.y == b.y &&
			a.z == b.z &&
			a.w == b.w
}