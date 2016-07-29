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
	static let keys: [Int] = [Int(arc4random()), Int(arc4random())]
	static let value: [Float] = [arc4random(), arc4random(), arc4random(), arc4random()].map{Float($0)/Float(UInt32.max)}
	
	static let f: Bool = false
	static let t: Bool = true
	
	let IS: [[Bool]] = [[f,t,f,f], [f,f,t,t], [f,f,t,f], [f,f,f,t]]
	let OS: [[Bool]] = [[t,f,f,f], [f,t,f,f], [f,f,t,f], [f,f,f,t]]
	
	func test0Insert() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let
				I: Cell = context.newCell(width: 4, label: "I"),
				H: Cell = context.newCell(width: 64, label: "H"),
				O: Cell = context.newCell(width: 4, label: "O")
			{
				context.chainCell(output: H, input: I)
				context.chainCell(output: H, input: H)
				context.chainCell(output: O, input: H)
				
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
	func test1Update() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let
				I: Cell = context.searchCell(label: "I").last,
				O: Cell = context.searchCell(label: "O").last
			{
				(0..<32768).forEach {
					
					I.oClear()
					O.iClear()
					
					I.active = IS[$0%4]
					O.answer = OS[$0%4]
					
					O.collect()
					I.correct(eps: 1/4.0)
				}
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
	func test2Validation() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let
				I: Cell = context.searchCell(label: "I").last,
				O: Cell = context.searchCell(label: "O").last
			{
				(0..<4).forEach {
					//print("epoch \($0)")
					I.oClear()
					O.iClear()
					
					I.active = IS[$0%4]
					print("validate: \(O.active)")
					
					XCTAssert(O.active==OS[$0%4])
				}
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

/*
class CellTests: XCTestCase {
	static let keys: [Int] = [Int(arc4random()), Int(arc4random())]
	static let value: [Float] = [arc4random(), arc4random(), arc4random(), arc4random()].map{Float($0)/Float(UInt32.max)}
	
	static let f: Bool = false
	static let t: Bool = true
	
	let IS: [[Bool]] = [[f,t,f,f], [f,f,t,t], [f,f,t,f], [f,f,f,t]]
	let OS: [[Bool]] = [[t,f,f,f], [f,t,f,f], [f,f,t,f], [f,f,f,t]]
	
	func test0Insert() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let
				I: Cell = context.newCell(width: 4, label: "I"),
				H0: Cell = context.newCell(width: 64, label: "H0", input: [I]),
				H1: Cell = context.newCell(width: 64, label: "H1", input: [I]),//, H0]),
				H2: Cell = context.newCell(width: 64, label: "H2", input: [I]),//, H0, H1]),
				H3: Cell = context.newCell(width: 64, label: "H3", input: [I]),//, H0, H1, H2]),
				H4: Cell = context.newCell(width: 64, label: "H4", input: [I]),//, H0, H1, H2, H3]),
				H5: Cell = context.newCell(width: 64, label: "H5", input: [I]),//, H0, H1, H2, H3, H4]),
				H6: Cell = context.newCell(width: 64, label: "H6", input: [I]),//, H0, H1, H2, H3, H4, H5]),
				H7: Cell = context.newCell(width: 64, label: "H7", input: [I]),//, H0, H1, H2, H3, H4, H5, H6]),
				_: Cell = context.newCell(width: 4, label: "O", input: [H0, H1, H2, H3, H4, H5, H6, H7])
			{
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
	func test1Update() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let
				I: Cell = context.searchCell(label: "I").last,
				O: Cell = context.searchCell(label: "O").last
			{
				(0..<32768).forEach {
					
					I.oClear()
					O.iClear()
					
					I.active = IS[$0%4]
					O.answer = OS[$0%4]
					
					O.collect()
					I.correct(eps: 1/4.0)
				}
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
	func test2Validation() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let
				I: Cell = context.searchCell(label: "I").last,
				O: Cell = context.searchCell(label: "O").last
			{
				(0..<4).forEach {
					//print("epoch \($0)")
					I.oClear()
					O.iClear()
					
					I.active = IS[$0%4]
					print("validate: \(O.active)")
					
					XCTAssert(O.active==OS[$0%4])
				}
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
	/*
	func test3Update() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let
				I: Cell = context.searchCell(label: "I").last,
				O: Cell = context.searchCell(label: "O").last
			{
				(0..<256).forEach {
					print("epoch: \($0)")
					
					I.oClear()
					O.iClear()
					
					O.answer = OS[$0%4]
					I.active = IS[$0%4]
					
					print("epoch: \(O.active)")
					I.correct(eps: 0.5)
					
				}
				context.commit()
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
	func test4Validation() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let
				I: Cell = context.searchCell(label: "I").last,
				O: Cell = context.searchCell(label: "O").last
			{
				(0..<4).forEach {
					I.oClear()
					O.iClear()
					
					I.active = IS[$0%4]
					
					XCTAssert(O.active==OS[$0%4])
				}
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
	*/
}
*/