//
//  cpuComputerTests.swift
//  ComputerTests
//
//  Created by Kota Nakano on 7/18/16.
//
//

import XCTest
@testable import Computer

class cpuComputerTests: XCTestCase {
	lazy var computer: Computer = self.implementation()
	func implementation() -> Computer {
		return cpuComputer()
	}
	func testNormal() {
		let n: Int = 1 << 18
		let M: Float = 500
		let S: Float = 100
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let u: Buffer = computer.newBuffer(data: NSData(bytes: [Float](count: n, repeatedValue: M), length: sizeof(Float)*n))
		let s: Buffer = computer.newBuffer(data: NSData(bytes: [Float](count: n, repeatedValue: S), length: sizeof(Float)*n))
		
		measureBlock {
			self.computer.normal(y, u: u, s: s, sync: false)
			self.computer.join()
		}
		
		let mu: Float = y.scalar.reduce(0){$0+$1}/Float(n)
		let sigma: Float = sqrtf(y.scalar.map{($0-mu)*($0-mu)}.reduce(0){$0+$1}/Float(n))
		
		print(mu, sigma)
		XCTAssert(abs(M-mu)<1.0)
		XCTAssert(abs(S-sigma)<3.0)
	}
	func testSigmoid() {
		let n: Int = 1 << 20
		
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let u: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let s: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let d: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		
		(0..<n).forEach {
			x.scalar[$0] = Float(M_PI) * Float($0 - n/2)/Float(n)
			u.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			s.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			d.scalar[$0] = 0.5 + 0.5 * tanhf((x.scalar[$0]-u.scalar[$0])/(s.scalar[$0]))
		}

		measureBlock {
			self.computer.sigmoid(y, x: x, u: u, s: s, sync: false)
			self.computer.join()
		}
		
		let rmse: Float = sqrtf(zip(y.scalar, d.scalar).map{($0.0-$0.1)*($0.0-$0.1)}.reduce(0){$0+$1}/Float(n))
		
		print(rmse)
		XCTAssert(rmse<1e-3)
	}
}
