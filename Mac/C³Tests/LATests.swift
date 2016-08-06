//
//  C_Tests.swift
//  C³Tests
//
//  Created by Kota Nakano on 6/6/16.
//
//
import Accelerate
import XCTest
@testable import C3

class LATests: XCTestCase {
	func test0() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent(CellTests.file)
			let context: Context = try Context(storage: url)
			
			let I: Cell = try context.newCell(width: 4, label: "I")
			let H: Cell = try context.newCell(width: 64, recur: true, buffer: true, label: "H")
			let G: Cell = try context.newCell(width: 64, recur: true, buffer: true, label: "G")
			let O: Cell = try context.newCell(width: 4, label: "O")
			
			try context.chainCell(output: O, input: G)
			try context.chainCell(output: H, input: G)
			try context.chainCell(output: G, input: H)
			try context.chainCell(output: H, input: I)
			
			try context.save()
			
		} catch let e {
			XCTFail(String(e))
			
		}
	}

}