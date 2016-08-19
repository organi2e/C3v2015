//
//  EdgeTests.swift
//  Mac
//
//  Created by Kota Nakano on 6/7/16.
//
//

import XCTest
import MNIST
@testable import C3

class MNISTTests: XCTestCase {
	static let file: String = "test.sqlite"
	func test0Insert() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent(MNISTTests.file)
			let context: Context = try Context(storage: url)
			if context.searchCell(width: 784, label: "MNIST_I").isEmpty {
				let I: Cell = try context.newCell(width: 784, label: "MNIST_I")
				let G: Cell = try context.newCell(width: 256, label: "MNIST_G")
				let F: Cell = try context.newCell(width: 256, label: "MNIST_F")
				let O: Cell = try context.newCell(width:  16, label: "MNIST_O")
				
				try context.chainCell(output: G, input: I)
				try context.chainCell(output: F, input: G)
				try context.chainCell(output: O, input: F)
				
				try context.save()
			} else {
				print("bypass")
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
				I: Cell = context.searchCell(width: 784, label: "MNIST_I").last,
				O: Cell = context.searchCell(width: 16,	label: "MNIST_O").last
			{
				try (0..<65536).forEach {
					let image: Image = Image.train[Int(arc4random_uniform(UInt32(Image.train.count)))]
					let ID: [Bool] = image.pixel.map{ 128 < $0 }
					let OD: [Bool] = (0..<10).map{ $0 == image.label }
					//var cnt: [Int] = [Int](count: 10, repeatedValue: 0)
					(0..<64).forEach {(_)in
						O.iClear()
						I.oClear()
						
						O.answer = OD
						I.active = ID
							
						O.collect()
						I.correct(eps: 1/64.0)
							
						//O.active[0..<10].enumerate().forEach { cnt[$0.0] = cnt[$0.0] + Int($0.1) }
					}
					print("epoch: \($0)")
					//print($0, zip(OD, cnt).map{ $0.0 ? "[\($0.1)]" : "\($0.1)"})
					context.join()
					try context.save()
				}
				context.join()
				try context.save()
			} else {
				XCTFail()
			}
		} catch let e {
			XCTFail(String(e))
		}
	}
	func test2Check() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent(MNISTTests.file)
			let context: Context = try Context(storage: url)
			if let
				I: Cell = context.searchCell(width: 784, label: "MNIST_I").last,
				O: Cell = context.searchCell(width: 16, label: "MNIST_O").last
			{
				(0..<64).forEach {
					let image: Image = Image.t10k[Int(arc4random_uniform(UInt32(Image.t10k.count)))]
					let ID: [Bool] = image.pixel.map{ 128 < $0 }
					let OD: [Bool] = (0..<10).map{ $0 == image.label }
					var cnt: [Int] = [Int](count: 10, repeatedValue: 0)
					(0..<64).forEach {(_)in
						
						I.oClear()
						O.iClear()
						
						I.active = ID
						O.active[0..<10].enumerate().forEach {
							cnt[$0.0] = cnt[$0.0] + Int($0.1)
						}
						
					}
					print($0, zip(OD, cnt).map{ $0.0 ? "[\($0.1)]" : "\($0.1)"})
				}
			} else {
				XCTFail()
			}
		} catch let e {
			XCTFail(String(e))
		}
	}
	/*
	func test3Validate() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let
				I: Cell = context.searchCell(label: "I").last,
				O: Cell = context.searchCell(label: "O").last
			{
				(0..<16).forEach {
					let image: Image = Image.train[Int(arc4random_uniform(UInt32(Image.train.count)))]
					let ID: [Bool] = image.pixel.map{ 0.5 < $0 }
					let OD: [Bool] = (0..<10).map{ $0 == image.label }
					var cnt: [Int] = [Int](count: 10, repeatedValue: 0)
					(0..<64).forEach {(_)in
						O.iClear()
						I.oClear()
						
						I.active = ID
						O.active.enumerate().forEach {
							cnt[$0.index] = cnt[$0.index] + Int($0.element)
						}
					}
					let e: [Double] = cnt.map{exp(Double($0))}
					let E: Double = e.reduce(0){$0+$1}
					let M: [Double] = e.map { $0 / E }
					let ce: Double = zip(M, OD).reduce(1) { (let e: Double, let p: (Double, Bool)) -> Double in
						return e * pow(p.0, Double(p.1)) * pow(1.0 - p.0, 1.0 - Double(p.1))
					}
					print($0, zip(OD, M).map{ $0.0 ? "[\($0.1)]" : "\($0.1)"}, ce)
					XCTAssert(0.5 < ce)
				}
			}
		} catch let e {
			XCTFail(String(e))
		}
	}
*/
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