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
			if let
				I: Cell = context.newCell(width: 4, label: "I"),
				H: Cell = context.newCell(width: 4, label: "H", input: [I]),
				_: Cell = context.newCell(width: 4, label: "G", input: [H]) {
				try context.store()
			}
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
			guard let O: Cell = context.searchCell(width: 4, label: "G").first, I: Cell = context.searchCell(width: 4, label: "I").first else {
				XCTFail()
				return
			}
			
			O.iClear()
			I.oClear()

			O.ideal = [false, false, false, true]
			I.state = [false, false, false, true]

			print("O: \(O.state)")
			I.correct(eps: 0.01)
			
			/*syntax sugar*/
			context.train([
				(
					["I":[false, false, false, false], /*"H":*/],
					["O":[false, false, false, false], /*...*/]
				),(
					["I":[false, false, false, true], /*"H":*/],
					["O":[false, false, false, true], /*...*/]
				)],
				count: 1024, 
				eps: 0.01
			)
			
			try context.save()
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

