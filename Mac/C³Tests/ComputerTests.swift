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
			let cpucomputer: Computer = cpuComputer()
			guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
				XCTFail()
				return
			}
			let gpucomputer: Computer = try mtlComputer(device: device)
			
			let m: Int = 4 * Int(arc4random_uniform(UInt32(16))) + 4
			let n: Int = 4 * Int(arc4random_uniform(UInt32(16))) + 4
			let X: [Float] = (0..<n).map{(_)in Float(arc4random_uniform(UInt32(256)))/256.0}
			let A: [Float] = (0..<n*m).map{(_)in Float(arc4random_uniform(UInt32(256)))/256.0}
			
			let result: [[Float]] = [cpucomputer, gpucomputer].map {
				let x: Buffer = $0.newBuffer(length: sizeof(Float)*n)
				let y: Buffer = $0.newBuffer(length: sizeof(Float)*m)
				let a: Buffer = $0.newBuffer(length: sizeof(Float)*m*n)
				
				(0..<n).forEach {
					x.scalar[$0] = X[$0]
				}
				(0..<n*m).forEach {
					a.scalar[$0] = A[$0]
				}
				
				$0.gemv(y: y, beta: 0, a: a, x: x, alpha: 1, n: n, m: m, trans: true)
				$0.join()
				
				return Array<Float>(y.scalar)
			}
			print("\(result[0]) vs \(result[1])")
			XCTAssert(result[0]==result[1])
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