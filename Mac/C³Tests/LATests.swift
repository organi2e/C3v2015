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
	
	func testDiv() {
		let x: Float = Float(arc4random())
		let y: Float = Float(arc4random())
		
		let X: la_object_t = la_splat_from_float(x, la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let Y: la_object_t = la_splat_from_float(y, la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		
		let Z: la_object_t = la_vector_from_splat(Y/X, 1)
		
		var z: Float = 0
		la_vector_to_float_buffer(&z, 1, Z)
		
		print("\(y/x) vs \(z)")
		XCTAssert((y/x-z)*(y/x-z)<1e-7)
	}
	func testDivs() {
		
		let rows: UInt = UInt(arc4random_uniform(1023)+1)
		let cols: UInt = UInt(arc4random_uniform(1023)+1)
		
		let count: Int = Int(rows*cols)
		
		let x: [Float] = (0..<count).map{(_)in Float(arc4random_uniform(256))+1.0}
		let y: [Float] = (0..<count).map{(_)in Float(arc4random_uniform(256))+1.0}
		
		let X: la_object_t = la_matrix_from_float_buffer(x, rows, cols, cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let Y: la_object_t = la_matrix_from_float_buffer(y, rows, cols, cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		
		let Z: la_object_t = Y / X
		XCTAssert( Z.rows == X.rows && Z.cols == X.cols )
		XCTAssert( Z.rows == Y.rows && Z.cols == Y.cols )
		
		let z: [Float] = [Float](count: count, repeatedValue: 0)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(z), cols, Z)
		
		(0..<z.count).forEach {
			XCTAssert((y[$0]/x[$0]-z[$0])*(y[$0]/x[$0]-z[$0])<1e-5)
		}
	}
	
	func testExp() {
		
		let rows: UInt = UInt(arc4random_uniform(1023)+1)
		let cols: UInt = UInt(arc4random_uniform(1023)+1)
		
		let count: Int = Int(rows*cols)
		
		let x: [Float] = (0..<count).map{(_)in Float(arc4random())/Float(UInt32.max)}
		let y: [Float] = x.map{exp($0)}
		
		let X: la_object_t = la_matrix_from_float_buffer(x, rows, cols, cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let Y: la_object_t = exp(X)
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(x), cols, Y)
		
		let e: [Float] = zip(x, y).map{$0.0-$0.1}
		let rmse: Float = sqrt(e.map{$0*$0}.reduce(0){$0+$1} / Float(count))
		
		XCTAssert( rmse < 1e-5 )

	}
	
	func testSQRT() {
		
		let rows: UInt = UInt(arc4random_uniform(1023)+1)
		let cols: UInt = UInt(arc4random_uniform(1023)+1)
		
		let count: Int = Int(rows*cols)
		
		let x: [Float] = (0..<count).map{(_)in Float(arc4random())/Float(UInt32.max)}
		let y: [Float] = x.map{sqrt($0)}
		
		let X: la_object_t = la_matrix_from_float_buffer(x, rows, cols, cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let Y: la_object_t = sqrt(X)
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(x), cols, Y)
		
		let e: [Float] = zip(x, y).map{$0.0-$0.1}
		let rmse: Float = sqrt(e.map{$0*$0}.reduce(0){$0+$1} / Float(count))
		
		XCTAssert( rmse < 1e-5 )
		
	}
	func testPdf() {
		
		let rows: UInt = UInt(arc4random_uniform(1023)+1)
		let cols: UInt = UInt(arc4random_uniform(1023)+1)
		
		let count: Int = Int(rows*cols)
		
		func p(let x: Float, let u: Float, let s: Float) -> Float {
			return exp(-0.5*(x-u)*(x-u)/s/s)/Float(sqrt(2.0*M_PI))/s
		}
		
		let x: [Float] = (0..<count).map{(_)in Float(arc4random())/Float(UInt32.max)}
		let u: [Float] = (0..<count).map{(_)in Float(arc4random())/Float(UInt32.max)}
		let s: [Float] = (0..<count).map{(_)in Float(arc4random())/Float(UInt32.max)}
		let y: [Float] = (0..<count).map{(let idx: Int)in p(x[idx], u: u[idx], s: s[idx])}
		
		let X: la_object_t = la_matrix_from_float_buffer(x, rows, cols, cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let U: la_object_t = la_matrix_from_float_buffer(u, rows, cols, cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let S: la_object_t = la_matrix_from_float_buffer(s, rows, cols, cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		let Y: la_object_t = pdf(x: X, mu: U, sigma: S)
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(x), cols, Y)
		
		let e: [Float] = zip(x, y).map{$0.0-$0.1}
		let rmse: Float = sqrt(e.map{$0*$0}.reduce(0){$0+$1} / Float(count))
		
		XCTAssert( rmse < 1e-5 )
		
	}
	func testNormal() {
		
		let rows: UInt = UInt(arc4random_uniform(1023)+1)
		let cols: UInt = UInt(arc4random_uniform(1023)+1)
		
		let count: Int = Int(rows*cols)
		
		let N: la_object_t = normal(rows: rows, cols: cols)
		let buffer: [Float] = [Float](count: count, repeatedValue: 0)
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), cols, N)
		
		let m: Float = buffer.reduce(0){$0+$1}/Float(count)
		let v: Float = buffer.map{($0-m)*($0-m)}.reduce(0){$0+$1}/Float(count)
		let s: Float = sqrt(v)
		
		print(m, s)
	}
	func testStep() {
		let rows: UInt = 4
		let cols: UInt = 4
		
		let count: Int = Int(rows*cols)
		
		let N: la_object_t = 4 + 4 * normal(rows: rows, cols: cols)
		let buffer0: [Float] = [Float](count: count, repeatedValue: 0)
		let buffer1: [Float] = [Float](count: count, repeatedValue: 0)
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer0), cols, N)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer1), cols, step(N))
		
		(0..<count).forEach {
			XCTAssert(( 0 < buffer0[$0] ? 1 : 0 ) == buffer1[$0])
		}
	}
	func testSign() {
		let rows: UInt = 4
		let cols: UInt = 4
		
		let count: Int = Int(rows*cols)
		
		let N: la_object_t = 4 + 4 * normal(rows: rows, cols: cols)
		let buffer0: [Float] = [Float](count: count, repeatedValue: 0)
		let buffer1: [Float] = [Float](count: count, repeatedValue: 0)
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer0), cols, N)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer1), cols, sign(N))
		
		(0..<count).forEach {
			XCTAssert(( 0 < buffer0[$0] ? 1 : 0 > buffer0[$0] ? -1 : 0 ) == buffer1[$0])
		}
	}
}
/*
class ContextTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			print(context.searchCell(label: "O").isEmpty)
			if context.searchCell(label: "O").isEmpty {
				if let
					I: Cell = context.newCell(width: 4, label: "I"),
					_: Cell = context.newCell(width: 4, label: "O", input: [I]) {
					print("created", context.insertedObjects.count, context.updatedObjects.count, context.deletedObjects.count)
				}
			}
			context.store(async: false)
		} catch let e {
			XCTFail(String(e))
		}
    }
	
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let _: Cell = context.newCell(width: 4) {
				print("created")
			}
			print("study")
			context.train([
				(
					["I":[true , false, false, false ]],
					["O":[false, false, false, true ]]
				),(
					["I":[false, true, false , false]],
					["O":[false, false, true , false]]
				),(
					["I":[false, false , true, false]],
					["O":[false, true , false, false]]
				),(
					["I":[false ,false, false, true ]],
					["O":[true , false, false, false]]
				)],
				count: 256,
				eps: 1/4.0
			)
			context.checkpoint(async: false)
			print(context.updatedObjects.count)
			context.store(async: false) {
				print($0)
			}
		} catch let e {
			XCTFail(String(e))
		}
    }
}
*/