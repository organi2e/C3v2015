//
//  BlobTests.swift
//  Mac
//
//  Created by Kota Nakano on 7/23/16.
//
//
/*
import Accelerate
import XCTest
@testable import C3
class LaObjetTests: XCTestCase {
	let M: Int = 4
	let N: Int = 4
	@nonobjc func uniform() -> [Float] {
		return(0..<N*M).map{(_)in Float(arc4random())/Float(UInt32.max)}
	}
	@nonobjc func uniform() -> Float {
		return Float(arc4random())/Float(UInt32.max)
	}
	func testAddVV() {
		let a: [Float] = uniform()
		let b: [Float] = uniform()
		let c: [Float] = zip(a,b).map { $0.0 + $0.1 }
		let A: LaObjet = LaMatrice(a, rows: a.count, cols: 1, deallocator: nil)
		let B: LaObjet = LaMatrice(b, rows: b.count, cols: 1, deallocator: nil)
		XCTAssert((A+B).array.elementsEqual(c))
	}
	
	func testSubVV() {
		let a: [Float] = uniform()
		let b: [Float] = uniform()
		let c: [Float] = zip(a,b).map { $0.0 - $0.1 }
		let A: LaObjet = LaMatrice(a, rows: a.count, cols: 1, deallocator: nil)
		let B: LaObjet = LaMatrice(b, rows: b.count, cols: 1, deallocator: nil)
		XCTAssert((A-B).array.elementsEqual(c))
	}
	
	func testMulVV() {
		let a: [Float] = uniform()
		let b: [Float] = uniform()
		let c: [Float] = zip(a,b).map { $0.0 * $0.1 }
		let A: LaObjet = LaMatrice(a, rows: a.count, cols: 1, deallocator: nil)
		let B: LaObjet = LaMatrice(b, rows: b.count, cols: 1, deallocator: nil)
		XCTAssert((A*B).array.elementsEqual(c))
	}
	
	func testDivVV() {
		let a: [Float] = uniform()
		let b: [Float] = uniform()
		let c: [Float] = zip(a,b).map { $0.0 / $0.1 }
		let A: LaObjet = LaMatrice(a, rows: a.count, cols: 1, deallocator: nil)
		let B: LaObjet = LaMatrice(b, rows: b.count, cols: 1, deallocator: nil)
		XCTAssert((A/B).array.elementsEqual(c))
	}
	
	func testAddSV() {
		let a: Float = uniform()
		let b: [Float] = uniform()
		let c: [Float] = b.map { a + $0 }
		let A: LaObjet = LaValuer(a)
		let B: LaObjet = LaMatrice(b, rows: b.count, cols: 1, deallocator: nil)
		XCTAssert((A+B).array.elementsEqual(c))
	}
	
	func testSubSV() {
		let a: Float = uniform()
		let b: [Float] = uniform()
		let c: [Float] = b.map { a - $0 }
		let A: LaObjet = LaValuer(a)
		let B: LaObjet = LaMatrice(b, rows: b.count, cols: 1, deallocator: nil)
		XCTAssert((A-B).array.elementsEqual(c))
	}
	
	func testSubVS() {
		let a: Float = uniform()
		let b: [Float] = uniform()
		let c: [Float] = b.map { $0 - a }
		let A: LaObjet = LaValuer(a)
		let B: LaObjet = LaMatrice(b, rows: b.count, cols: 1, deallocator: nil)
		XCTAssert((B-A).array.elementsEqual(c))
	}
	
	func testMulSV() {
		let a: Float = uniform()
		let b: [Float] = uniform()
		let c: [Float] = b.map { a * $0 }
		let A: LaObjet = LaValuer(a)
		let B: LaObjet = LaMatrice(b, rows: b.count, cols: 1, deallocator: nil)
		XCTAssert((A*B).array.elementsEqual(c))
	}
	
	func testDivSV() {
		let a: Float = uniform()
		let b: [Float] = uniform()
		let c: [Float] = b.map { a / $0 }
		let A: LaObjet = LaValuer(a)
		let B: LaObjet = LaMatrice(b, rows: b.count, cols: 1, deallocator: nil)
		XCTAssert((A/B).array.elementsEqual(c))
		if !(A/B).array.elementsEqual(c) {
			print((A/B).array)
			print(c)
		}
	}
	
	func testDivVS() {
		let a: Float = uniform()
		let b: [Float] = uniform()
		let c: [Float] = b.map { $0 / a }
		let A: LaObjet = LaValuer(a)
		let B: LaObjet = LaMatrice(b, rows: b.count, cols: 1, deallocator: nil)
		XCTAssert((B/A).array.elementsEqual(c))
		if !(B/A).array.elementsEqual(c) {
			print((B/A).array)
			print(c)
		}
	}

}
*/