//
//  BlobTests.swift
//  Mac
//
//  Created by Kota Nakano on 7/23/16.
//
//

import XCTest
@testable import C3

class BlobTests: XCTestCase {
	static let name: String = "key\(arc4random())"
	static let value: [UInt8] = [UInt8(arc4random_uniform(256)), UInt8(arc4random_uniform(256))]
	func test0() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let blob: Blob = context.new() {
				blob.name = BlobTests.name
				XCTAssert(blob.name==BlobTests.name)
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
	func test1() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let blob: Blob = context.fetch(["name": BlobTests.name]).first {
				
				XCTAssert(blob.name==BlobTests.name)
				
				blob[0] = BlobTests.value[0]
				blob[7] = BlobTests.value[1]
				
				XCTAssert(blob[0] == BlobTests.value[0])
				XCTAssert(blob[7] == BlobTests.value[1])
				
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
	func test2() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let blob: Blob = context.fetch(["name": BlobTests.name]).first {
				
				XCTAssert(blob.name==BlobTests.name)
				
				XCTAssert(blob[0] == BlobTests.value[0])
				XCTAssert(blob[7] == BlobTests.value[1])
				
				blob[0] = BlobTests.value[1]
				blob[7] = BlobTests.value[0]
				
				XCTAssert(blob[0] == BlobTests.value[1])
				XCTAssert(blob[7] == BlobTests.value[0])
				
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
	func test3() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let blob: Blob = context.fetch(["name": BlobTests.name]).first {
				
				XCTAssert(blob.name==BlobTests.name)
				
				XCTAssert(blob[0] == BlobTests.value[1])
				XCTAssert(blob[7] == BlobTests.value[0])
				
			} else {
				XCTFail()
			}
		} catch let e {
			XCTFail(String(e))
		}
	}
}