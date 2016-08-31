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
		return [-14, 4]
	}
	
	func f(x: [Float]) -> Float {
		return x[0]*x[0]/20 + x[1]*x[1]
	}
	
	func J(x: [Float]) -> [Float] {
		return[x[0]/10, 2*x[1]]
	}
	
	func testSGD() {
		var x: [Float] = X
		let fp = fopen("/tmp/SGD.raw", "wb")
		for _ in 0...40 {
			fwrite(x, sizeof(Float), 2, fp)
			let g = J(x)
			x[0] -= g[0]*0.9
			x[1] -= g[1]*0.9
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
		let cg: GradientOptimizer = ConjugateGradient(dim: 2, type: .DY)
		let fp = fopen("/tmp/Conjugate.raw", "wb")
		var x: [Float] = X
		for _ in 0...40 {
			fwrite(x, sizeof(Float), 2, fp)
			let g = J(x)
			let G = LaMatrice(g, rows: 2, cols: 1)
			let X = LaMatrice(x, rows: 2, cols: 1)
			let h = cg.optimize(Δx: G, x: X).array
			x[0] -= h[0]/2
			x[1] -= h[1]/2
		}
		print(x, f(x))
		fclose(fp)
	}
	
	func testMomentum() {
		let optimizer: GradientOptimizer = Momentum(dim: 2, α: 0.9)
		let fp = fopen("/tmp/Momentum.raw", "wb")
		var x: [Float] = X
		for _ in 0...40 {
			fwrite(x, sizeof(Float), 2, fp)
			let g = J(x)
			let G = LaMatrice(g, rows: 2, cols: 1)
			let X = LaMatrice(x, rows: 2, cols: 1)
			let h = optimizer.optimize(Δx: G, x: X).array
			x[0] -= h[0]/2
			x[1] -= h[1]/2
		}
		print(x, f(x))
		fclose(fp)
	}
	
	func testAdam() {
		let optimizer: GradientOptimizer = Adam(dim: 2, α: 0.5)
		let fp = fopen("/tmp/Adam.raw", "wb")
		var x: [Float] = X
		for _ in 0...40 {
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
		let optimizer: GradientOptimizer = SMORMS3(dim: 2)
		let fp = fopen("/tmp/SMORMS3.raw", "wb")
		var x: [Float] = X
		for _ in 0...40 {
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
		for _ in 0...40 {
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
		let qn: GradientOptimizer = QuasiNewton(dim: 2, type: .SR1)
		let fp = fopen("/tmp/QuasiNewton.raw", "wb")
		var x: [Float] = X
		for _ in 0...40 {
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
X, Y = meshgrid(arange(-10,10,0.1), arange(-10,10,0.1))
Z = sqrt((X**2)/20 + Y**2)
contour(X, Y, Z, 16, colors='k')
for k in ['SGD', 'Adam', 'Conjugate', 'SMORMS3', 'QuasiNewton','Momentum']:
	x = fromfile('/tmp/%s.raw'%k, 'float32')
	plot(x[0::2],x[1::2],label=k)
	rc('font',family='Times New Roman')

legend(loc=1)
xlim([-10,10])
ylim([-10,10])
draw()
show(block=False)
*/

/*
from matplotlib.pylab import *
figure('render')
for i in range(1,20):
	clf()
	X, Y = meshgrid(arange(-10,10,0.1), arange(-10,10,0.1))
	Z = sqrt((X**2)/20 + Y**2)
	contour(X, Y, Z, 16, colors='k')
	for k in ['SGD', 'Momentum', 'Adam', 'RMSProp', 'SMORMS3', 'QuasiNewton', 'Conjugate']:
		x = fromfile('/tmp/%s.raw'%k, 'float32')
		print(1)
		plot(x[0:2*i:2],x[1:2*i:2],label=k)
		print(2)
	rc('font',family='Times New Roman')
	legend(loc=1)
	xlim([-10,10])
	ylim([-10,10])
	draw()
	show(block=False)
	savefig('%02d.png'%i)
*/