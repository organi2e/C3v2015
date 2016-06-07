//
//  C_Tests.swift
//  C³Tests
//
//  Created by Kota Nakano on 6/6/16.
//
//
import Foundation
import simd
import XCTest
@testable import C3
class C3Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let
				I: Cell = context.newCell(width: 16, label: "I"),
				H: Cell = context.newCell(width: 16, label: "H", input: [I]),
				_: Cell = context.newCell(width: 16, label: "G", input: [H]) {
				print("created")
				context.join()
				try context.store()
			}
		} catch let e {
			print(e)
		}
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
	
	func testComputer() {
		do {
			let cpucomputer: Computer = try Computer()
			let gpucomputer: Computer = try Computer(device: MTLCreateSystemDefaultDevice())
			
			XCTAssert(gpucomputer.poweredbygpu)
			
			[cpucomputer].forEach {
				let m: Int = 4
				let n: Int = 8
				let x: Buffer = $0.newBuffer(length: sizeof(Float)*n)
				let y: Buffer = $0.newBuffer(length: sizeof(Float)*m)
				let a: Buffer = $0.newBuffer(length: sizeof(Float)*m*n)

				(0..<n).forEach {
					x.scalar[$0] = Float(arc4random_uniform(UInt32(256)))
				}
				(0..<n*m).forEach {
					a.scalar[$0] = Float(arc4random_uniform(UInt32(256)))
				}
				let z: float4 = a.matrix[0] * x.vector[0] + a.matrix[1] * x.vector[1]
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
	
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let O: Cell = context.searchCell(label: "G").first {
				O.clear()
				O.chain {
					print("\($0.label) traced")
				}
				O.correct([], eps: 0.0)
			}
			context.join()
			
		} catch let e {
			print(e)
		}
    }
    /*
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    */
}

func == (let a: float4, let b: float4) -> Bool {
	return
		a.x == b.x &&
		a.y == b.y &&
		a.z == b.z &&
		a.w == b.w
}
