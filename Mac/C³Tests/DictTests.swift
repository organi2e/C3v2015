//
//  ComputerTests.swift
//  Mac
//
//  Created by Kota Nakano on 6/7/16.
//
//

import XCTest
@testable import C3

class DictTests: XCTestCase {
	/*
	static let key: Int = Int(arc4random())
	static let value: Int = Int(arc4random())
	
	func testSearch0 () {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let dict: Dict = context.newDict() {
				dict.key = DictTests.key
				dict.value = DictTests.value
			}
			context.store(async: false) {(_)in
				XCTFail()
			}
			print("create: \(DictTests.key)")
		} catch let e {
			XCTFail(String(e))
		}
	}
	
	func testSearch1 () {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let dict: Dict = context.searchDict(["key": DictTests.key]).first {
				XCTAssert( DictTests.value == dict.value as? Int )
			} else {
				XCTFail()
			}
		} catch let e {
			XCTFail(String(e))
		}
	}
*/
}

