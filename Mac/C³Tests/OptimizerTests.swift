//
//  LaObjetTests.swift
//  Mac
//
//  Created by Kota Nakano on 8/30/16.
//
//
/*
import XCTest
@testable import C3
class OptimizerTests: XCTestCase {
	
	func f(x: [Float]) -> Float {
		let X: Float = x[0]
		let Y: Float = x[1]
		return(
			(X+2)*(X+2)/100+(Y)*(Y)
		)
	}
	
	func J(x: [Float]) -> [Float] {
		let X: Float = x[0]
		let Y: Float = x[1]
		return[
			2*(X-2)/100,
			2*(Y-8)
		]
	}
	
	func optimize(fp: UnsafeMutablePointer<FILE> = nil, factory: Int -> GradientOptimizer) {
		let dim: Int = 2
		let optimizer: GradientOptimizer = factory(dim)
		var x: [Float] = (0..<dim).map {(_)in Float(M_PI)*Float(arc4random())/Float(arc4random())}
		for _ in 0...80 {
			if fp != nil {
				fwrite(x, sizeof(Float), 2, fp)
			}
			let g = J(x)
			let G = LaMatrice(g, rows: 2, cols: 1)
			let X = LaMatrice(x, rows: 2, cols: 1)
			let h = optimizer.optimize(Δx: G, x: X).array
			x[0] -= h[0]
			x[1] -= h[1]
		}
		print(x)
	}
	
	func testSGD() {
		let fp = fopen("/tmp/SGD.raw", "wb")
		let factory = SGD.factory()
		optimize(fp, factory: factory)
		fclose(fp)
	}
	
	func testMomentum() {
		let fp = fopen("/tmp/Momentum.raw", "wb")
		let factory = Momentum.factory()
		optimize(fp, factory: factory)
		fclose(fp)
	}
	
	func testAdam() {
		let fp = fopen("/tmp/Adam.raw", "wb")
		optimize(fp, factory: Adam.factory())
		fclose(fp)
	}
	
	func testRMSProp() {
		let fp = fopen("/tmp/RMSprop.raw", "wb")
		optimize(fp, factory: RMSprop.factory())
		fclose(fp)
	}
	
	func testSMORMS3() {
		let fp = fopen("/tmp/SMORMS3.raw", "wb")
		optimize(fp, factory: SMORMS3.factory())
		fclose(fp)
	}
	
	func testConjugateGradient() {
		let fp = fopen("/tmp/ConjugateGradient.raw", "wb")
		optimize(fp, factory: ConjugateGradient.factory(.HagerZhang, η: 0.5))
		fclose(fp)
	}
	
	func testQuasiNewton() {
		let fp = fopen("/tmp/QuasiNewton.raw", "wb")
		optimize(fp, factory: QuasiNewton.factory(.SymmetricRank1))
		fclose(fp)
	}
}

/*
from matplotlib.pylab import *
figure('render')
clf()
X, Y = meshgrid(arange(-12,12,0.1), arange(-12,12,0.1))
Z = sqrt(X*X/100+Y*Y)
contour(X, Y, Z, 8, colors='silver')
for k in ['SGD', 'Momentum', 'Adam', 'RMSProp', 'SMORMS3', 'ConjugateGradient', 'QuasiNewton']:
	x = fromfile('/tmp/%s.raw'%k, 'float32')
	plot(x[0:2*i:2],x[1:2*i:2],label=k)
	rc('font',family='Times New Roman')

legend(loc=2)
xlim([-12,12])
ylim([-12,12])
draw()
show(block=False)
*/

/*
from matplotlib.pylab import *
figure('render')
for i in range(1,40):
	clf()
	X, Y = meshgrid(arange(-12,12,0.1), arange(-12,12,0.1))
	Z = sqrt((X-2)*(X-2)/100+(Y-8)*(Y-8))
	contour(X, Y, Z, 8, colors='silver')
	for k in ['SGD', 'Momentum', 'Adam', 'RMSProp', 'SMORMS3', 'QuasiNewton', 'ConjugateGradient']:
		x = fromfile('/tmp/%s.raw'%k, 'float32')
		plot(x[0:2*i:2],x[1:2*i:2],label=k)
	rc('font',family='Times New Roman')
	legend(loc=3)
	xlim([-12,12])
	ylim([-12,12])
	draw()
	show(block=False)
	savefig('%03d.png'%i,figsize=(16,9),dpi=72)
*/
*/