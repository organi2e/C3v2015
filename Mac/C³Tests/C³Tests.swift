//
//  C_Tests.swift
//  C³Tests
//
//  Created by Kota Nakano on 6/6/16.
//
//
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
	
	func testMatrixMult() {
		do {
			let context: Context = try Context()
			let a: Buffer = context.newBuffer(length: 16)
			let b: Buffer = context.newBuffer(length: 16)
			let c: Buffer = context.newBuffer(length: 16)
			
			b.vector[2] = float4(1.0, 2.0, 3.0, 4.0)
			a.scalar[0] = 1.0
			a.vector[1].y = 2.0
			a.matrix[0][2][2] = 3.0
			a.matrix[0][3][3] = 4.0
			
			c.matrix[0] = a.matrix[0] * b.matrix[0]
			
			XCTAssert(UnsafePointer<Void>(a.raw.bytes) == UnsafePointer<Void>(a.mtl!.contents()))
			
			print(Array(c.scalar))
			
		} catch let e {
			print(e)
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
