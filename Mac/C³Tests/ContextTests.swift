//
//  C_Tests.swift
//  C³Tests
//
//  Created by Kota Nakano on 6/6/16.
//
//
import Foundation
import XCTest
@testable import C3
class ContextTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			print(context.searchCell(label: "O").isEmpty)
			if context.searchCell(label: "O").isEmpty {
				if let
					I: Cell = context.newCell(width: 4, label: "I"),
					_: Cell = context.newCell(width: 4, label: "O", input: [I]) {
					print("created", context.insertedObjects.count, context.updatedObjects.count, context.deletedObjects.count)
				}
			}
			if let _: Cell = context.newCell(width: 4) {
				print("created")
			}
			context.store(async: false)
		} catch let e {
			XCTFail(String(e))
		}
    }
	
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			/*syntax sugar*/
			print("study")
			context.train([
				(
					["I":[false, false, false, true ]],
					["O":[false, false, false, true ]]
				),(
					["I":[false, false, true , false]],
					["O":[false, false, true , false]]
				),(
					["I":[false, true , false, false]],
					["O":[false, true , false, false]]
				),(
					["I":[true , false, false, false]],
					["O":[true , false, false, false]]
				)],
				count: 64,
				eps: 1/4.0
			)
			context.checkpoint(async: false)
			print(context.updatedObjects.count)
			context.store(async: false)
		} catch let e {
			XCTFail(String(e))
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

