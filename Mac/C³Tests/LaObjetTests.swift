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
	
	func f(x: [Float]) -> Float {
		let X: Float =      (x[0]-2) * (x[0]-2)
		let Y: Float = 40 * (x[1]+2) * (x[1]+2)
		let XY: Float = -exp(-x[0]*x[0]-x[1]*x[1])
		return X + Y + XY
	}
	
	func J(x: [Float]) -> [Float] {
		let dX0: Float = 2 * (x[0]-2)
		let dX1: Float = 2 * x[0] * exp(-x[0]*x[0]-x[1]*x[1])
		let dY0: Float = 80 * (x[1]+2)
		let dY1: Float = 2 * x[1] * exp(-x[0]*x[0]-x[1]*x[1])
		return[dX0+dX1, dY0+dY1]
	}
	
	func testSGD() {
		var x: [Float] = [14, 14]
		for _ in 0..<128 {
			let g = J(x)
			x[0] -= g[0]/128.0
			x[1] -= g[1]/128.0
		}
		print(x, f(x))
	}
	
	func testNCG() {
		let ncg = NewtonConjugateGradient(dim: 2)
		var x: [Float] = [4, 4]
		for _ in 0..<128 {
			let g = J(x)
			let G = LaMatrice(g, rows: 2, cols: 1)
			let X = LaMatrice(x, rows: 2, cols: 1)
			let h = ncg.update(g: G, x: X).array
			x[0] -= h[0]/128.0
			x[1] -= h[1]/128.0
		}
		print(x, f(x))
	}
	
	func testCG() {
		let cg = ConjugateGradient(dim: 2)
		var x: [Float] = [14, 14]
		for _ in 0..<128 {
			let g = J(x)
			let G = LaMatrice(g, rows: 2, cols: 1)
			let X = LaMatrice(x, rows: 2, cols: 1)
			let h = cg.update(g: G, x: X).array
			x[0] -= h[0]/128.0
			x[1] -= h[1]/128.0
		}
		print(x, f(x))
	}

	func testBFGS() {
		let bfgs = BFGS(dim: 2)
		let fp = fopen("/tmp/GRAD.raw", "wb")
		var x: [Float] = [4, 4]
		for _ in 0..<80 {
			let g = J(x)
			let G = LaMatrice(g, rows: 2, cols: 1)
			let X = LaMatrice(x, rows: 2, cols: 1)
			let h = bfgs.update(g: G, x: X).array
			x[0] -= h[0]/2.0
			x[1] -= h[1]/2.0
			fwrite(x, sizeof(Float), 2, fp)
		}
		print(x, f(x))
		fclose(fp)
	}
}