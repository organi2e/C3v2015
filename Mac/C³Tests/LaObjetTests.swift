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
		func f(x: [Float]) -> Float {
			return (x[0]-2) * (x[0]-2) + 20 * (x[1]+2) * (x[1]+2)
		}
		func J(x: [Float]) -> [Float] {
			return[
				2*(x[0]-2),
				40*(x[1]+2)
			]
		}
		let bfgs = BFGS(dim: 2)
		let fp = fopen("/tmp/GRAD.raw", "wb")
		var x: [Float] = [40, 40]
		for _ in 0..<64 {
			var e = f(x)
			var g = J(x)
			let G = LaMatrice(g, rows: 2, cols: 1)
			let X = LaMatrice(x, rows: 2, cols: 1)
			let h = bfgs.update(g: G, x: X).array
			x[0] -= h[0]/4.0
			x[1] -= h[1]/4.0
			fwrite(x, sizeof(Float), 2, fp)
		}
		print(x, f(x))
		fclose(fp)
	}
}