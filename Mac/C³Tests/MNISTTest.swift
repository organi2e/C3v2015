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
				H10: Cell = context.newCell(width: 128, label: "H10", input: [H0]),
				H11: Cell = context.newCell(width: 128, label: "H11", input: [H0]),
				H12: Cell = context.newCell(width: 128, label: "H12", input: [H0]),
				H13: Cell = context.newCell(width: 128, label: "H13", input: [H0]),
			/*
				H20: Cell = context.newCell(width: 32, label: "H20", input: [H10, H11, H12, H13]),
				H21: Cell = context.newCell(width: 32, label: "H21", input: [H10, H11, H12, H13]),
				H22: Cell = context.newCell(width: 32, label: "H22", input: [H10, H11, H12, H13]),
				H23: Cell = context.newCell(width: 32, label: "H23", input: [H10, H11, H12, H13]),
				*/
				 _: Cell = context.newCell(width:  10, label: "O", input: [H10, H11, H12, H13])
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
					var suc: Int = 0
					var fal: Int = 0
					Image.train.enumerate().forEach { (let idx: Int, let image: Image)in
						print("img. \(idx)")
						let ID: [Bool] = image.pixel.map{ 0.5 < $0 }
						let OD: [Bool] = (0..<10).map{ $0 == image.label }
						
						(0..<64).forEach {
							O.iClear()
							I.oClear()
						
							I.active = ID
							O.answer = OD
							
							O.collect()
							I.correct(eps: 1.0/4.0)
							
							if $0 == 0 {
								if O.active == OD {
									suc = suc + 1
								} else {
									fal = fal + 1
								}
							}
						}
					}
					print("epoch", $0, "presicion", Double(suc)/Double(suc+fal))
					context.store() {(_)in
						XCTFail()
					}
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
