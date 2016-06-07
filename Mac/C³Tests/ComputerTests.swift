//
//  ComputerTests.swift
//  Mac
//
//  Created by Kota Nakano on 6/7/16.
//
//

import Foundation
import Accelerate
import simd
import XCTest
@testable import C3

class ComputerTests: XCTestCase {
	let eps: Float = 0.00000001
	let sigma: Float = 2.0
	func testSigmoid() {
		do {
			let cpucomputer: Computer = cpuComputer()
			guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
				XCTFail()
				return
			}
			let gpucomputer: Computer = try mtlComputer(device: device)
			let n: Int = 16 * Int(arc4random_uniform(UInt32(16))) + 16
			let X: [Float] = (0..<n).map{(_)in Float(arc4random_uniform(UInt32(256)))/64.0-2.0}
			let C: [Float] = (0..<n).map{(_)in Float(arc4random_uniform(UInt32(256)))/64.0-2.0}
				
			let result: [[Float]] = [cpucomputer, gpucomputer].map {
				let x: Buffer = $0.newBuffer(length: sizeof(Float)*n)
				let y: Buffer = $0.newBuffer(length: sizeof(Float)*n)
				let c: Buffer = $0.newBuffer(length: sizeof(Float)*n)
					
				(0..<n).forEach {
					x.scalar[$0] = X[$0]
				}
				(0..<n).forEach {
					c.scalar[$0] = C[$0]
				}
				
				$0.sigmoid(y: y, x: x, c: c, sigma: sigma, n: n)
				$0.join()
					
				return Array<Float>(y.scalar)
			}
			let E: [Float] = zip ( result [ 0 ], result [ 1 ] ) .map { $0.0 - $0.1 }
			let RMSE: Float = E .map { $0 * $0 } .reduce ( 0 ) { $0 + $1 }
			XCTAssert ( RMSE < eps )
		} catch let e {
			print(e)
			XCTFail()
		}
	}
	func testGEMV() {
		do {
			let cpucomputer: Computer = cpuComputer()
			guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
				XCTFail()
				return
			}
			let gpucomputer: Computer = try mtlComputer(device: device)
			
			let result: Bool = [true, false].map{( let trans: Bool )->Bool in
				let m: Int = 16 * Int(arc4random_uniform(UInt32(16))) + 16
				let n: Int = 16 * Int(arc4random_uniform(UInt32(16))) + 16
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
					
					$0.gemv(y: y, beta: 0, a: a, x: x, alpha: 1, n: n, m: m, trans: trans)
					$0.join()
					
					return Array<Float>(y.scalar)
				}
				let E: [Float] = zip(result[0], result[1] ).map{ $0.0 - $0.1 }
				let RMSE: Float = sqrt ( E.map { $0 * $0 }.reduce ( 0 ) { $0.0 + $0.1 } )
				return RMSE < eps
			}.reduce(true){$0.0&&$0.1}
			XCTAssert(result)
		} catch let e {
			print(e)
			XCTFail()
		}
	}
	func testCPUSPD() {
		let computer: Computer = cpuComputer()
		let N: Int = 1024
		let M: Int = 1024
		let K: Int = 64
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*N)
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*M)
		let a: Buffer = computer.newBuffer(length: sizeof(Float)*M*N)
		(0..<M*N).forEach {
			a.scalar[$0] = Float(arc4random_uniform(UInt32(65536)))
		}
		(0..<N).forEach {
			x.scalar[$0] = Float(arc4random_uniform(UInt32(65536)))
		}
		measureBlock {
			(0..<K).forEach {(_)in
				computer.gemv(y: y, beta: 0.0, a: a, x: x, alpha: 1.0, n: N, m: M, trans: false)
			}
			computer.join()
		}
	}
	func testMTLSPD() {
		do {
			guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
				throw NSError(domain: "Here", code: 0, userInfo: nil)
			}
			let N: Int = 1024
			let M: Int = 1024
			let K: Int = 64
			let computer: Computer = try mtlComputer(device: device)
			let x: Buffer = computer.newBuffer(length: sizeof(Float)*N)
			let y: Buffer = computer.newBuffer(length: sizeof(Float)*M)
			let a: Buffer = computer.newBuffer(length: sizeof(Float)*M*N)
			(0..<M*N).forEach {
				a.scalar[$0] = Float(arc4random_uniform(UInt32(65536)))
			}
			(0..<N).forEach {
				x.scalar[$0] = Float(arc4random_uniform(UInt32(65536)))
			}
			measureBlock {
				(0..<K).forEach {(_)in
					computer.gemv(y: y, beta: 0.0, a: a, x: x, alpha: 1.0, n: N, m: M, trans: false)
				}
				computer.join()
			}
		} catch {
			XCTFail()
		}
	}
}
