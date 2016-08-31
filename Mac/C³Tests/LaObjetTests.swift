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
		let dX0: Float =  1 * (x[0]+3)
		let dX1: Float = 2 * x[0] * exp(-x[0]*x[0]-x[1]*x[1])
		let dY0: Float = 80 * (x[1]+5)
		let dY1: Float = 2 * x[1] * exp(-x[0]*x[0]-x[1]*x[1])
		return[dX0+dX1, dY0+dY1]
	}
	
	func testSGD() {
		var x: [Float] = [14, 14]
		let fp = fopen("/tmp/SGD.raw", "wb")
		for _ in 0...40 {
			fwrite(x, sizeof(Float), 2, fp)
			let g = J(x)
			x[0] -= g[0]/41.0
			x[1] -= g[1]/41.0
		}
		print(x, f(x))
		fclose(fp)
	}
	
	func testCG() {
		/*
		FletcherReeves
		PolakRibière
		HestenesStiefe
		DaiYuan
		*/
		let cg: GradientOptimizer = ConjugateGradient(dim: 2, condition: .DaiYuan)
		let fp = fopen("/tmp/DAIYUAN.raw", "wb")
		var x: [Float] = [14, 14]
		for _ in 0...40 {
			fwrite(x, sizeof(Float), 2, fp)
			let g = J(x)
			let G = LaMatrice(g, rows: 2, cols: 1)
			let X = LaMatrice(x, rows: 2, cols: 1)
			let h = cg.optimize(Δx: G, x: X).array
			x[0] -= h[0]/41.0
			x[1] -= h[1]/41.0
		}
		print(x, f(x))
		fclose(fp)
	}
	
	func testQuasiNewton() {
		let qn: GradientOptimizer = QuasiNewton(dim: 2, type: .BroydenFletcherGoldfarbShanno)
		let fp = fopen("/tmp/BFGS.raw", "wb")
		var x: [Float] = [14, 14]
		for _ in 0...40 {
			fwrite(x, sizeof(Float), 2, fp)
			let g = J(x)
			let G = LaMatrice(g, rows: 2, cols: 1)
			let X = LaMatrice(x, rows: 2, cols: 1)
			let h = qn.optimize(Δx: G, x: X).array
			x[0] -= h[0]/2.0
			x[1] -= h[1]/2.0
		}
		print(x, f(x))
		fclose(fp)
	}

	func testBFGS() {
		let bfgs = BFGS(dim: 2)
		let fp = fopen("/tmp/BFGS.raw", "wb")
		var x: [Float] = [14, 14]
		for _ in 0...40 {
			fwrite(x, sizeof(Float), 2, fp)
			let g = J(x)
			let G = LaMatrice(g, rows: 2, cols: 1)
			let X = LaMatrice(x, rows: 2, cols: 1)
			let h = bfgs.update(g: G, x: X).array
			x[0] -= h[0]/2.0
			x[1] -= h[1]/2.0
		}
		print(x, f(x))
		fclose(fp)
	}
}

/*
from matplotlib.pylab import *
figure()
clf()
x = fromfile('/tmp/SGD.raw', 'float32')
plot(x[0::2],x[1::2],'r-')
x = fromfile('/tmp/DAIYUAN.raw', 'float32')
plot(x[0::2],x[1::2],'g-')
x = fromfile('/tmp/BFGS.raw', 'float32')
plot(x[0::2],x[1::2],'b-')
legend(['SGD', 'DAIYUAN', 'BGFS'],loc=2)
xlim([-20,20])
ylim([-20,20])
draw()
show()
*/