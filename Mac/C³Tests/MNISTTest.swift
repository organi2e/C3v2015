//
//  EdgeTests.swift
//  Mac
//
//  Created by Kota Nakano on 6/7/16.
//
//

import XCTest
import MNIST
import C3

class MNISTTests: XCTestCase {
	static let file: String = "test.sqlite"
	func test0Insert() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent(MNISTTests.file)
			let context: Context = try Context(storage: url)
			if
				context.searchCell(width: 784, label: "I").isEmpty,
			let
				H0: Cell = context.newCell(width: 784, label: "I"),
				H1: Cell = context.newCell(width: 500, label: "H0", input: [H0]),
				H2: Cell = context.newCell(width: 150, label: "H1", input: [H1]),
				 _: Cell = context.newCell(width:  10, label: "O", input: [H2])
			{
				print("new")
				context.store() {(_)in
					XCTFail()
				}
			} else {
				print("will load")
			}
		} catch let e {
			XCTFail(String(e))
		}
	}
	func test1Update() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent(MNISTTests.file)
			let context: Context = try Context(storage: url)
			if let
				I: Cell = context.searchCell(label: "I").last,
				O: Cell = context.searchCell(label: "O").last
			{
				(0..<256).forEach {
					let image: Image = Image.train[Int(arc4random_uniform(UInt32(Image.train.count)))]
					let ID: [Bool] = image.pixel.map{ 0.5 < $0 }
					let OD: [Bool] = (0..<10).map{ $0 == image.label }
					var cnt: [Int] = [Int](count: 10, repeatedValue: 0)
					(0..<64).forEach {(_)in
						O.iClear()
						I.oClear()
						
						I.active = ID
						O.answer = OD
							
						O.collect()
						I.correct(eps: 1/64.0)
							
						O.active.enumerate().forEach {
							cnt[$0.0] = cnt[$0.0] + Int($0.1)
						}
						/*
						if $0 == 0 {
							if O.active == OD {
								suc = suc + 1
							} else {
								fal = fal + 1
							}
						}
						*/
					}
					print("\($0)) \(OD) \(cnt)")
				}
			} else {
				XCTFail()
			}
		} catch let e {
			XCTFail(String(e))
		}
	}
	func test2Validate() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let
				I: Cell = context.searchCell(label: "I").last,
				O: Cell = context.searchCell(label: "O").last
			{
				var suc: Int = 0
				var fal: Int = 0
				Image.t10k[0..<100].forEach { (let image: Image)in
					let ID: [Bool] = image.pixel.map{ 0.5 < $0 }
					let OD: [Bool] = (0..<10).map{ $0 == image.label }
						
					I.oClear()
					O.iClear()
						
					I.active = ID
					if O.active == OD {
						suc = suc + 1
					} else {
						fal = fal + 1
					}
				}
				print("t10k presicion", Double(suc)/Double(suc+fal))
			}
		} catch let e {
			XCTFail(String(e))
		}
	}
	/*
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
*/
}
