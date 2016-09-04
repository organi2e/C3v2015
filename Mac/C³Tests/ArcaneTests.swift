//
//  ArcaneTest.swift
//  Mac
//
//  Created by Kota Nakano on 8/30/16.
//
//
import XCTest
@testable import C3
class ArcaneTest: XCTestCase {
	let context: Context = try!Context()
	func rmse(x: [Float], _ y: [Float]) -> Float {
		return sqrt(zip(x, y).map { $0 - $1 }.map { $0 * $0 }.reduce(0) { $0.0 + $0.1 })
	}
	func uf(u: [Float]) -> Float{
		return (
			(u[0]+3)*(u[0]+3) +
			(u[1]+8)*(u[1]+8)
		)
	}
	func ug(u: [Float]) -> [Float] {
		return [
			2*(u[0]+3),
			2*(u[1]+8)
		]
	}
	func sf(s: [Float]) -> Float{
		return (
			(s[0]-3)*(s[0]-3) +
			(s[1]-3)*(s[1]-3)
		)
	}
	func sg(s: [Float]) -> [Float] {
		return [
			2*(s[0]-0.1),
			2*(s[1]-3)
		]
	}
	func uniform(count: Int) -> [Float] {
		return (0..<count).map {(_)in
			Float(arc4random())/Float(UInt32.max)
		}
	}
	func testUpdate() {
		
		let rows: Int = 2
		let cols: Int = 1
		
		context.optimizerFactory = ConjugateGradient.factory(.HagerZhang)
		let a: Arcane! = context.new()

		a.resize(rows: rows, cols: cols)
		a.adjust(μ: 1, σ: 1)
		
		(0..<64).forEach {(_)in
			
			print(a.μ.array)
			print(a.σ.array)
			
			let gu: [Float] = ug(a.μ.array)
			let gs: [Float] = sg(a.σ.array)
			let Δμ: LaObjet = LaMatrice(gu, rows: rows, cols: cols, deallocator: nil)
			let Δσ: LaObjet = LaMatrice(gs, rows: rows, cols: cols, deallocator: nil)
			a.update(FalseDistribution.self, Δμ: Δμ, Δσ: Δσ)
			
		}
		
		print(a.μ.array)
		print(a.σ.array)
		
	}
	
	func testGaussianUpdate() {
		
		let rows: Int = 4
		let cols: Int = 1
		
//		let η: Float = 0.5

		let μ: Float = -1.5
		let σ: Float =  0.25
		let λ: Float = 1 / σ

		let d: [Float] = uniform(rows*cols)
		
		let dχ: [Float] = d.map { $0 * exp(-0.5*(μ*λ)*(μ*λ))/sqrt(2*Float(M_PI)) }
		let dμ: [Float] = dχ.map { $0 * λ }
		let dσ: [Float] = dχ.map { $0 * -μ * λ }
		
		let Δχ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		let Δμ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		let Δσ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		
		GaussianDistribution.derivate(Δχ: Δχ, Δμ: Δμ, Δσ: Δσ, Δ: d, μ: [Float](count: rows*cols, repeatedValue: μ), λ: [Float](count: rows*cols, repeatedValue: λ))
		
		if 1e-6 < rmse(dχ, Δχ) {
			XCTFail()
		}
		
		if 1e-6 < rmse(dμ, Δμ) {
			XCTFail()
		}
		
		if 1e-6 < rmse(dσ, Δσ) {
			XCTFail()
			print(dσ)
			print(Δσ)
		}
		
		let Δμk: [Float] = Δμ
		let Δσk: [Float] = Δσ.map { $0 * σ }
		
		let Δ = GaussianDistribution.Δ((μ: LaMatrice(Δμ, rows: rows, cols: cols), σ: LaMatrice(Δσ, rows: rows, cols: cols)), μ: LaValuer(μ), σ: LaValuer(σ), Σ: (μ: LaValuer(μ), λ: LaValuer(λ)))
		
		Δ.μ.getBytes(Δμ)
		Δ.σ.getBytes(Δσ)
		
		if 1e-6 < rmse(Δμk, Δμ) {
			XCTFail()
			print(Δμk)
			print(Δμ)
		}
		
		if 1e-6 < rmse(Δσk, Δσ) {
			XCTFail()
			print(Δσk)
			print(Δσ)
		}
		
		
		
	}

	func testCauchyUpdate() {
		
		let rows: Int = 4
		let cols: Int = 1
		
		//		let η: Float = 0.5
		
		let μ: Float = -1.5
		let σ: Float =  0.25
		let λ: Float = 1 / σ
		
		let d: [Float] = uniform(rows*cols)
		
		let dχ: [Float] = d.map { $0 / ( 1 + μ * μ * λ * λ ) / Float(M_PI) }
		let dμ: [Float] = dχ.map { $0 * λ }
		let dσ: [Float] = dχ.map { $0 * -μ * λ * λ }
		
		let Δχ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		let Δμ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		let Δσ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		
		CauchyDistribution.derivate(Δχ: Δχ, Δμ: Δμ, Δσ: Δσ, Δ: d, μ: [Float](count: rows*cols, repeatedValue: μ), λ: [Float](count: rows*cols, repeatedValue: λ))
		
		if 1e-6 < rmse(dχ, Δχ) {
			XCTFail()
		}
		
		if 1e-6 < rmse(dμ, Δμ) {
			XCTFail()
		}
		
		if 1e-6 < rmse(dσ, Δσ) {
			XCTFail()
			print(dσ)
			print(Δσ)
		}
		
		let Δμk: [Float] = Δμ
		let Δσk: [Float] = Δσ
		
		let Δ = CauchyDistribution.Δ((μ: LaMatrice(Δμ, rows: rows, cols: cols), σ: LaMatrice(Δσ, rows: rows, cols: cols)), μ: LaValuer(μ), σ: LaValuer(σ), Σ: (μ: LaValuer(μ), λ: LaValuer(λ)))
		
		Δ.μ.getBytes(Δμ)
		Δ.σ.getBytes(Δσ)
		
		if 1e-6 < rmse(Δμk, Δμ) {
			XCTFail()
			print(Δμk)
			print(Δμ)
		}
		
		if 1e-6 < rmse(Δσk, Δσ) {
			XCTFail()
			print(Δσk)
			print(Δσ)
		}
		
		
		
	}

	
}
