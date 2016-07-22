//
//  EdgeTests.swift
//  Mac
//
//  Created by Kota Nakano on 6/7/16.
//
//

import XCTest
@testable import C3

class CellTests: XCTestCase {
	static let key: Int = Int(arc4random())
	static let value: [Float] = [arc4random(), arc4random(), arc4random(), arc4random()].map{Float($0)/Float(UInt32.max)}
	func testSearch0() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let cell: Cell = context.newCell(width: 4, label: "test\(CellTests.key)") {
				
				print("init \(CellTests.key)")
				print("\(CellTests.value[0])")
				print("\(CellTests.value[1])")
				print("\(CellTests.value[2])")
				print("\(CellTests.value[3])")
				
				cell[0] = CellTests.value[0]
				cell[1] = CellTests.value[1]
				cell[2] = CellTests.value[2]
				cell[3] = CellTests.value[3]
				
				cell.save()
				cell.load()
				
				XCTAssert(cell[0]==CellTests.value[0])
				XCTAssert(cell[1]==CellTests.value[1])
				XCTAssert(cell[2]==CellTests.value[2])
				XCTAssert(cell[3]==CellTests.value[3])

				context.store() {(_)in
					XCTFail()
				}
				print("done")
				
			} else {
				XCTFail()
			}
		} catch let e {
			XCTFail(String(e))
		}
	}
	
	func testSearch1() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let cell: Cell = context.searchCell(label: "test\(CellTests.key)").first {
				
				print("test1")
				print("\(cell[0]) vs \(CellTests.value[0])")
				print("\(cell[1]) vs \(CellTests.value[1])")
				print("\(cell[2]) vs \(CellTests.value[2])")
				print("\(cell[3]) vs \(CellTests.value[3])")
				
				XCTAssert(cell[0]==CellTests.value[0])
				XCTAssert(cell[1]==CellTests.value[1])
				XCTAssert(cell[2]==CellTests.value[2])
				XCTAssert(cell[3]==CellTests.value[3])
				
				cell[0] = CellTests.value[3]
				cell[1] = CellTests.value[2]
				cell[2] = CellTests.value[1]
				cell[3] = CellTests.value[0]
				
				XCTAssert(cell[0]==CellTests.value[3])
				XCTAssert(cell[1]==CellTests.value[2])
				XCTAssert(cell[2]==CellTests.value[1])
				XCTAssert(cell[3]==CellTests.value[0])
				
				cell.save()
				cell.load()
				
				context.store() {(_)in
					XCTFail()
				}
			} else {
				print(context.searchCell(label: "test\(CellTests.key)"))
				XCTFail()
			}
		} catch let e {
			XCTFail(String(e))
		}
	}
	func testSearch2() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let cell: Cell = context.searchCell(label: "test\(CellTests.key)").first {
				
				print("test2")
				print("\(cell[0]) vs \(CellTests.value[3])")
				print("\(cell[1]) vs \(CellTests.value[2])")
				print("\(cell[2]) vs \(CellTests.value[1])")
				print("\(cell[3]) vs \(CellTests.value[0])")
				
				XCTAssert(cell[0]==CellTests.value[3])
				XCTAssert(cell[1]==CellTests.value[2])
				XCTAssert(cell[2]==CellTests.value[1])
				XCTAssert(cell[3]==CellTests.value[0])
				
				cell[0] = CellTests.value[3]
				cell[1] = CellTests.value[2]
				cell[2] = CellTests.value[1]
				cell[3] = CellTests.value[0]
				
				context.store() {(_)in
					XCTFail()
				}
			} else {
				XCTFail()
			}
		} catch let e {
			XCTFail(String(e))
		}
	}
}

