//
//  LaObjetTests.swift
//  Mac
//
//  Created by Kota Nakano on 8/30/16.
//
//
import XCTest
@testable import C3
class LaObjetTests: XCTestCase {
	func testBFGS() {
		func f(x: [Float]) -> Float { return(x[0]+1)*(x[0]+1)*(x[0]+1) + exp((x[1]+2)*(x[1]+2)-2) }
		func J(x: [Float]) -> [Float] { return[2*(x[0]+1), 2*(x[1]+2) * exp((x[1]+2)*(x[1]+2)-2)] }
		let bfgs = BFGS(dim: 2)
		var x: [Float] = [Float(arc4random())/Float(UINT32_MAX)-0.5, Float(arc4random())/Float(UINT32_MAX)-0.5]
		for _ in 0..<256 {
			let g = J(x)
			let h = bfgs.update(g: g, x: x).array
			x[0] -= 0.5 * h[0]
			x[1] -= 0.5 * h[1]
		}
		print(x, f(x))
	}
}