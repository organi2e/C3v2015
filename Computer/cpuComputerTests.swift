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
	func testGEMV() {
	
	}
	func testSQ() {
		let n: Int = 1 << order
		
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let d: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		
		(0..<n).forEach {
			x.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			d.scalar[$0] = x.scalar[$0] * x.scalar[$0]
		}
		
		measureBlock {
			self.computer.sq(y, x, sync: false)
			self.computer.join()
		}
		
		let rmse: Float = sqrtf(zip(y.scalar, d.scalar).map{($0.0-$0.1)*($0.0-$0.1)}.reduce(0){$0+$1}/Float(n))
		if 1e-5 < rmse {
			if n < 64 {
				print(Array(d.scalar))
				print(Array(y.scalar))
			}
			print(rmse)
			XCTFail()
		}
	}
	func testSQRT() {
		let n: Int = 1 << order
		
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let d: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		
		(0..<n).forEach {
			x.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			d.scalar[$0] = Float(sqrt(Double(x.scalar[$0])))
		}
		
		measureBlock {
			self.computer.sqrt(y, x, sync: false)
			self.computer.join()
		}
		
		let rmse: Float = sqrtf(zip(y.scalar, d.scalar).map{($0.0-$0.1)*($0.0-$0.1)}.reduce(0){$0+$1}/Float(n))
		if 1e-5 < rmse {
			if n < 64 {
				print(Array(d.scalar))
				print(Array(y.scalar))
			}
			print(rmse)
			XCTFail()
		}
	}
	func testEXP() {
		let n: Int = 1 << order
		
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let d: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		
		(0..<n).forEach {
			x.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			d.scalar[$0] = Float(exp(Double(x.scalar[$0])))
		}
		
		measureBlock {
			self.computer.exp(y, x, sync: false)
			self.computer.join()
		}
		
		let rmse: Float = sqrtf(zip(y.scalar, d.scalar).map{($0.0-$0.1)*($0.0-$0.1)}.reduce(0){$0+$1}/Float(n))
		if 1e-5 < rmse {
			if n < 64 {
				print(Array(d.scalar))
				print(Array(y.scalar))
			}
			print(rmse)
			XCTFail()
		}
	}
	func testPDF() {
		let n: Int = 1 << order
		
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let u: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let s: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let d: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		
		(0..<n).forEach {
			x.scalar[$0] = Float($0 - n/2)/Float(n)
			u.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			s.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			
			let lambda: Double = (Double(x.scalar[$0]) - Double(u.scalar[$0]))/Double(s.scalar[$0])
			d.scalar[$0] = Float(exp(-0.5*lambda*lambda)/Double(s.scalar[$0])/sqrt(2.0*M_PI))
		}
		
		measureBlock {
			self.computer.pdf(y, x: x, u: u, s: s, sync: false)
			self.computer.join()
		}
		
		let rmse: Float = sqrtf(zip(y.scalar, d.scalar).map{($0.0-$0.1)*($0.0-$0.1)}.reduce(0){$0+$1}/Float(n))
		if 1e-5 < rmse {
			if n < 64 {
				print(Array(d.scalar))
				print(Array(y.scalar))
			}
			print(rmse)
			XCTFail()
		}
	}
	func testCDF() {
		let n: Int = 1 << order
		
		let y: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let x: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let u: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let s: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		let d: Buffer = computer.newBuffer(length: sizeof(Float)*n)
		
		(0..<n).forEach {
			x.scalar[$0] = Float($0 - n/2)/Float(n)
			u.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			s.scalar[$0] = Float(arc4random())/Float(UInt32.max)
			
			let lambda: Double = (Double(x.scalar[$0]) - Double(u.scalar[$0]))/Double(s.scalar[$0])*M_SQRT1_2
			d.scalar[$0] = Float(0.5*erfc(-lambda))
		}
		
		measureBlock {
			self.computer.cdf(y, x: x, u: u, s: s, sync: false)
			self.computer.join()
		}
		
		let rmse: Float = sqrtf(zip(y.scalar, d.scalar).map{($0.0-$0.1)*($0.0-$0.1)}.reduce(0){$0+$1}/Float(n))
		if 1e-5 < rmse {
			if n < 64 {
				print(Array(d.scalar))
				print(Array(y.scalar))
			}
			print(rmse)
			XCTFail()
		}
	}
	func testPow() {
	
	}
	func testSigmoid() {
		let n: Int = 1 << order
		
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
		if 1e-5 < rmse {
			if n < 64 {
				print(Array(d.scalar))
				print(Array(y.scalar))
			}
			print(rmse)
			XCTFail()
		}
	}
	func testNormal() {
		let n: Int = 1 << order
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
		
		if 1.0 < abs(M-mu) || 3.0 < abs(S-sigma) {
			print(mu, sigma)
			XCTFail()
		}
	}
	lazy var computer: Computer = self.implementation()
	let order: Int = 18
	func implementation() -> Computer {
		return cpuComputer()
	}

}
