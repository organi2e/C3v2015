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
	static let file: String = "test.sqlite"
	static let keys: [Int] = [Int(arc4random()), Int(arc4random())]
	static let value: [Float] = [arc4random(), arc4random(), arc4random(), arc4random()].map{Float($0)/Float(UInt32.max)}
	
	static let f: Bool = false
	static let T: Bool = true
	
	//let IS: [[Bool]] = [[f,f,f,T], [f,f,T,f], [f,f,T,T], [f,T,f,f]]
	//let OS: [[Bool]] = [[f,f,f,T], [f,f,T,f], [f,T,f,f], [T,f,f,f]]
	
	let IS: [[Bool]] = [[f,f,f,T], [f,f,T,f], [f,T,f,f], [f,f,T,f]]
	let OS: [[Bool]] = [[f,f,f,T], [f,f,T,f], [f,T,f,f], [T,f,f,f]]
	
	func test0Insert() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent(CellTests.file)
			let context: Context = try Context(storage: url)
			
			let I: Cell = try context.newCell(width: 4, label: "I")
			let H: Cell = try context.newCell(width: 100, recur: true, buffer: true, label: "H")
			let G: Cell = try context.newCell(width: 100, recur: true, buffer: true, label: "G")
			let O: Cell = try context.newCell(width: 4, label: "O")
			
			try context.chainCell(output: O, input: G)
			try context.chainCell(output: G, input: H)
			try context.chainCell(output: H, input: I)
			
			try context.save()
			
		} catch let e {
			XCTFail(String(e))
		}
	}
	func test1Update() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent(CellTests.file)
			let context: Context = try Context(storage: url)
			if let
				I: Cell = context.searchCell(label: "I").last,
				O: Cell = context.searchCell(label: "O").last
			{
				(0..<4000).forEach {
					
					let ID: [Bool] = IS[$0%4]
					let OD: [Bool] = OS[$0%4]
					
					print("epoch: \($0)")
					
					(0..<64).forEach {(let iter: Int)in
						
						O.iClear()
						I.oClear()
					
						O.answer = OD
						I.active = ID

						O.collect()
						I.correct(eps: 1/64.0)
						
					}
					
				}
			}
			try context.save()
		} catch let e {
			XCTFail(String(e))
		}
	}
	
	func test2Validation() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent(CellTests.file)
			let context: Context = try Context(storage: url)
			if let
				I: Cell = context.searchCell(label: "I").last,
				O: Cell = context.searchCell(label: "O").last
			{
				(0..<4).forEach {
					let ID: [Bool] = IS[$0%4]
					let OD: [Bool] = OS[$0%4]
					var DC: [Int] = [Int](count: 10, repeatedValue: 0)
					(0..<32).forEach {(_)in
						
						I.oClear()
						O.iClear()
						
						I.active = ID
						O.active.enumerate().forEach {
							DC[$0.index] = DC[$0.index] + Int($0.element)
						}
					}
					print(zip(OD, DC).map{ $0.0 ? "[\($0.1)]" : "\($0.1)" })
				}
				
			} else {
				XCTFail()
			}

		} catch let e {
			XCTFail(String(e))
		}
	}
	/*
	func test0Insert() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let
				I: Cell = context.newCell(width: 4, label: "I"),
				H: Cell = context.newCell(width: 16, label: "H"),
				G: Cell = context.newCell(width: 16, label: "G"),
				F: Cell = context.newCell(width: 16, label: "F"),
				E: Cell = context.newCell(width: 16, label: "E"),
				D: Cell = context.newCell(width: 16, label: "D"),
				C: Cell = context.newCell(width: 16, label: "C"),
				B: Cell = context.newCell(width: 16, label: "B"),
				A: Cell = context.newCell(width: 16, label: "A"),
				O: Cell = context.newCell(width: 4, label: "O")
			{
				context.chainCell(output: O, input: F)
				context.chainCell(output: O, input: D)
				context.chainCell(output: O, input: A)
				
				context.chainCell(output: H, input: I)
				context.chainCell(output: H, input: G)
				
				context.chainCell(output: G, input: F)
				
				context.chainCell(output: F, input: E)
				
				context.chainCell(output: E, input: H)
				context.chainCell(output: E, input: C)
				
				context.chainCell(output: G, input: F)
				
				context.chainCell(output: F, input: E)
				
				context.chainCell(output: E, input: C)
				context.chainCell(output: E, input: H)
				
				context.chainCell(output: D, input: I)
				
				context.chainCell(output: C, input: B)
				
				context.chainCell(output: B, input: E)
				
				context.chainCell(output: A, input: I)
				context.chainCell(output: A, input: A)
				
				
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
				(0..<1024).forEach {
					let ID: [Bool] = IS[$0%4]
					let OD: [Bool] = OS[$0%4]
					(0..<16).forEach {(_)in
						I.oClear()
						O.iClear()
			
						context.join()
						
						I.active = ID
						O.answer = OD
					
						O.collect()
						I.correct(eps: 1/8.0)
					}
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
					let ID: [Bool] = IS[$0%4]
					let OD: [Bool] = OS[$0%4]
					var DC: [Int] = [Int](count: 10, repeatedValue: 0)
					(0..<64).forEach {(_)in
						I.oClear()
						O.iClear()
						I.active = ID
						O.active.enumerate().forEach {
							if $0.element {
								DC[$0.index] = DC[$0.index] + 1
							}
						}
					}
					print(zip(OD, DC).map{ $0.0 ? "[\($0.1)]" : "\($0.1)" })
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