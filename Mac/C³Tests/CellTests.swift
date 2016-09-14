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
	let context: Context = try!Context()
	func testCollect() {
		context.optimizerFactory = SGD.factory(η: 0.05)
		let type: DistributionType = .Gauss
		let I: Cell = try! context.newCell(type, width: 4, label: "I")
		let H: Cell = try! context.newCell(type, width:256, label: "H", input: [I])
		let G: Cell = try! context.newCell(type, width:256, label: "G", input: [H])
		let F: Cell = try! context.newCell(type, width:256, label: "F", input: [G])
		let O: Cell = try! context.newCell(type, width: 4, label: "O", input: [F])
		
		let IS: [[Bool]] = [
			UInt8(3).bitPattern,
			UInt8(2).bitPattern,
			UInt8(1).bitPattern,
			UInt8(0).bitPattern
		]
		let OS: [[Bool]] = [
			UInt8(3).oneHotEncoding,
			UInt8(2).oneHotEncoding,
			UInt8(1).oneHotEncoding,
			UInt8(0).oneHotEncoding
		]
		
		for k in 0..<1024*2 {
			//print("epoch: \(k)", terminator: "\r")
			for _ in 0..<1 {
				
				I.correct_clear()
				O.collect_clear()
				
				O.answer = OS[k%OS.count]
				I.active = IS[k%IS.count]
				
				O.collect()
				I.correct()
			}
			
		}
		for k in 0..<4 {
			var cnt: [Int] = [Int](count: 4, repeatedValue: 0)
			
			for _ in 0..<16 {
				
				I.correct_clear()
				O.collect_clear()
				
				I.active = IS[k%IS.count]
				O.active.enumerate().forEach {
					cnt[$0.index] = cnt[$0.index] + Int($0.element)
				}
			}
			print(cnt)
		}
		
	}
}