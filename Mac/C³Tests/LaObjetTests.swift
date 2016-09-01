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

	var X: [Float] {
		return [-10, 5]
	}
	var iter: Int {
		return 60
	}
	var rate: Float {
		return 0.1
	}
	
	
	func f(x: [Float]) -> Float {
		let X: Float = x[0]
		let Y: Float = x[1]
		return(
			(X)*(X)/100+Y*Y
		)
	}
	
	func J(x: [Float]) -> [Float] {
		let X: Float = x[0]
		let Y: Float = x[1]
		return[
			2*X/100,
			2*Y
		]
	}
	
	func testSGD() {
		var x: [Float] = X
		let fp = fopen("/tmp/SGD.raw", "wb")
		for _ in 0...iter {
			fwrite(x, sizeof(Float), 2, fp)
			let g = J(x)
			x[0] -= g[0]*0.97
			x[1] -= g[1]*0.97
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
		let optimizer: GradientOptimizer = ConjugateGradient(dim: 2, type: ConjugateGradient.types.DY)
		let fp = fopen("/tmp/Conjugate.raw", "wb")
		var x: [Float] = X
		for _ in 0...iter {
			fwrite(x, sizeof(Float), 2, fp)
			let g = J(x)
			let G = LaMatrice(g, rows: 2, cols: 1)
			let X = LaMatrice(x, rows: 2, cols: 1)
			let h = optimizer.optimize(Δx: G, x: X).array
			x[0] -= h[0]/8
			x[1] -= h[1]/8
		}
		print(x, f(x))
		fclose(fp)
	}
	
	func testMomentum() {
		let optimizer: GradientOptimizer = Momentum(dim: 2, α: 0.9)
		let fp = fopen("/tmp/Momentum.raw", "wb")
		var x: [Float] = X
		for _ in 0...iter {
			fwrite(x, sizeof(Float), 2, fp)
			let g = J(x)
			let G = LaMatrice(g, rows: 2, cols: 1)
			let X = LaMatrice(x, rows: 2, cols: 1)
			let h = optimizer.optimize(Δx: G, x: X).array
			x[0] -= h[0] * 0.1
			x[1] -= h[1] * 0.1
		}
		print(x, f(x))
		fclose(fp)
	}
	
	func testAdam() {
		let optimizer: GradientOptimizer = Adam(dim: 2, α: 0.01)
		let fp = fopen("/tmp/Adam.raw", "wb")
		var x: [Float] = X
		for _ in 0...iter {
			fwrite(x, sizeof(Float), 2, fp)
			let g = J(x)
			let G = LaMatrice(g, rows: 2, cols: 1)
			let X = LaMatrice(x, rows: 2, cols: 1)
			let h = optimizer.optimize(Δx: G, x: X).array
			x[0] -= h[0]
			x[1] -= h[1]
		}
		print(x, f(x))
		fclose(fp)
	}
	
	func testSMORMS3() {
		let optimizer: GradientOptimizer = SMORMS3(dim: 2, α: 0.9)
		let fp = fopen("/tmp/SMORMS3.raw", "wb")
		var x: [Float] = X
		for _ in 0...iter {
			fwrite(x, sizeof(Float), 2, fp)
			let g = J(x)
			let G = LaMatrice(g, rows: 2, cols: 1)
			let X = LaMatrice(x, rows: 2, cols: 1)
			let h = optimizer.optimize(Δx: G, x: X).array
			x[0] -= h[0]
			x[1] -= h[1]
		}
		print(x, f(x))
		fclose(fp)
	}
	
	func testRMSProp() {
		let optimizer: GradientOptimizer = RMSprop(dim: 2, γ: 0.5)
		let fp = fopen("/tmp/RMSprop.raw", "wb")
		var x: [Float] = X
		for _ in 0...iter {
			fwrite(x, sizeof(Float), 2, fp)
			let g = J(x)
			let G = LaMatrice(g, rows: 2, cols: 1)
			let X = LaMatrice(x, rows: 2, cols: 1)
			let h = optimizer.optimize(Δx: G, x: X).array
			x[0] -= h[0]
			x[1] -= h[1]
		}
		print(x, f(x))
		fclose(fp)
	}
	
	func testQuasiNewton() {
		let qn: GradientOptimizer = QuasiNewton(dim: 2, type: .SymmetricRank1)
		let fp = fopen("/tmp/QuasiNewton.raw", "wb")
		var x: [Float] = X
		for _ in 0...iter {
			fwrite(x, sizeof(Float), 2, fp)
			let g = J(x)
			let G = LaMatrice(g, rows: 2, cols: 1)
			let X = LaMatrice(x, rows: 2, cols: 1)
			let h = qn.optimize(Δx: G, x: X).array
			x[0] -= h[0]/2
			x[1] -= h[1]/2
		}
		print(x, f(x))
		fclose(fp)
	}
}

/*
from matplotlib.pylab import *
figure('render')
clf()
X, Y = meshgrid(arange(-15,15,0.1), arange(-15,15,0.1))
Z = sqrt(X*X+Y*Y)
contour(X, Y, Z, 16, colors='gray')
for k in ['SGD', 'Momentum', 'Adam', 'RMSProp', 'SMORMS3', 'QuasiNewton', 'Conjugate']:
	x = fromfile('/tmp/%s.raw'%k, 'float32')
	plot(x[0:2*i:2],x[1:2*i:2],label=k)

legend(loc=1)
xlim([-15,15])
ylim([-15,15])
draw()
show(block=False)
*/

/*
from matplotlib.pylab import *
figure('render')
for i in range(1,60):
	clf()
	X, Y = meshgrid(arange(-12,12,0.1), arange(-12,12,0.1))
	Z = sqrt(X*X/100+Y*Y)
	contour(X, Y, Z, 8, colors='silver')
	for k in ['SGD', 'Momentum', 'Adam', 'RMSProp', 'SMORMS3', 'QuasiNewton', 'Conjugate']:
		x = fromfile('/tmp/%s.raw'%k, 'float32')
		plot(x[0:2*i:2],x[1:2*i:2],label=k)
	rc('font',family='Times New Roman')
	legend(loc=1)
	xlim([-12,12])
	ylim([-12,12])
	draw()
	show(block=False)
	savefig('%03d.png'%i,figsize=(16,9),dpi=72)
*/