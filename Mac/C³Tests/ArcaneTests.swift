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
		let err: [Float] = zip(x, y).map { $0.0 - $0.1 }
		let se: [Float] = err.map { $0 * $0 }
		let mse: Float = se.reduce(0) { $0.0 + $0.1 }
		let rmse: Float = sqrt(mse / Float(se.count))
		return rmse
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
			2*(s[1]-0.1)
		]
	}
	func uniform(count: Int) -> [Float] {
		return (0..<count).map {(_)in
			Float(arc4random())/Float(UInt32.max)
		}
	}
	/*
	func testμσ() {
		
		let count: Int = 16
		
		let logμ_src: [Float] = uniform(count)
		let logσ_src: [Float] = uniform(count)
		
		let μ_src: [Float] = logμ_src
		let σ_src: [Float] = logσ_src.map { log(1+exp($0)) }
		
		let μ_dst: [Float] = [Float](count: count, repeatedValue: 0)
		let σ_dst: [Float] = [Float](count: count, repeatedValue: 0)
		
		Arcane.μ(UnsafeMutablePointer<Float>(μ_dst), logμ: logμ_src, count: count)
		Arcane.σ(UnsafeMutablePointer<Float>(σ_dst), logσ: logσ_src, count: count)
		
		if 1e-6 < rmse(μ_src, μ_dst) {
			XCTFail()
			print(μ_src)
			print(μ_dst)
		}
		
		if 1e-6 < rmse(σ_src, σ_dst) {
			XCTFail()
			print(σ_src)
			print(σ_dst)
		}
		
		let logμ_dst: [Float] = [Float](count: count, repeatedValue: 0)
		let logσ_dst: [Float] = [Float](count: count, repeatedValue: 0)
		
		Arcane.logμ(UnsafeMutablePointer<Float>(logμ_dst), μ: μ_src, count: count)
		Arcane.logσ(UnsafeMutablePointer<Float>(logσ_dst), σ: σ_src, count: count)
		
		if 1e-5 < rmse(logμ_src, logμ_dst) {
			XCTFail()
			print(logμ_src)
			print(logμ_dst)
		}
		
		if 1e-6 < rmse(logσ_src, logσ_dst) {
			XCTFail()
			print(logσ_src)
			print(logσ_dst)
		}
	
		let gradμ_src: [Float] = [Float](count: count, repeatedValue: 1)
		let gradσ_src: [Float] = σ_src.map { 1 - exp(-$0) }
		
		let gradμ_dst: [Float] = [Float](count: count, repeatedValue: 0)
		let gradσ_dst: [Float] = [Float](count: count, repeatedValue: 0)
		
		Arcane.gradμ(UnsafeMutablePointer<Float>(gradμ_dst), μ: μ_src, count: count)
		Arcane.gradσ(UnsafeMutablePointer<Float>(gradσ_dst), σ: σ_src, count: count)
		
		if 1e-6 < rmse(gradμ_src, gradμ_dst) {
			XCTFail()
			print(gradμ_src)
			print(gradμ_dst)
		}
		
		if 1e-6 < rmse(gradσ_src, gradσ_dst) {
			XCTFail()
			print(gradσ_src)
			print(gradσ_dst)
		}
		
	}*/
	
	func testUpdate() {
		let a: Arcane! = context.new()
		
		let μ: Float = 1.0
		let σ: Float = 3.0
		a.adjust(μ: μ, σ: σ)
	}
	
	func testUpdate2() {
		
		let rows: Int = 2
		let cols: Int = 1
		
		context.optimizerFactory = Refraction.factory(r: 0.5, η: 0.5)
		let a: Arcane! = context.new()

		a.resize(rows: rows, cols: cols)
		a.adjust(μ: 1, σ: 1)
		
		(0..<64).forEach {(_)in
			
			
			let gu: [Float] = ug(a.μ.array)
			let gs: [Float] = sg(a.σ.array)
			let Δμ: LaObjet = LaMatrice(gu, rows: rows, cols: cols, deallocator: nil)
			let Δσ: LaObjet = LaMatrice(gs, rows: rows, cols: cols, deallocator: nil)
			
			a.update(FalseDistribution.self, Δμ: Δμ, Δσ: Δσ)
			
		}
		
	}
	
	func sign(x: Float) -> Float {
		return 0 < x ? 1 : 0 > x ? -1 : 0
	}
	
	func testGaussianUpdate() {
		
		let rows: Int = 4
		let cols: Int = 4
		
		let μ: Float = (Float(arc4random())+1)/(Float(UInt32.max)+1) * 2.0 - 1.0
		let σ: Float = (Float(arc4random())+1)/(Float(UInt32.max)+1)
		let λ: Float = 1 / σ

		let d: [Float] = uniform(rows*cols)
		
		let dχ: [Float] = d.map { sign($0) * exp(-0.5*(μ*λ)*(μ*λ)) / Float(sqrt(2*M_PI)) }
		let dμ: [Float] = dχ.map { $0 * λ }
		let dσ: [Float] = dμ.map { $0 * -μ * λ * λ }
		
		let Δχ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		let Δμ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		let Δσ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		
		GaussianDistribution.derivate((	χ: UnsafeMutablePointer<Float>(Δχ),
										μ: UnsafeMutablePointer<Float>(Δμ),
										σ: UnsafeMutablePointer<Float>(Δσ)),
		                              δ: d,
		                              μ: [Float](count: rows*cols, repeatedValue: μ),
		                              λ: [Float](count: rows*cols, repeatedValue: λ),
		                              count: rows*cols
		)
		
		if 1e-6 < rmse(dχ, Δχ) {
			XCTFail()
			print(dχ)
			print(Δχ)
		}
		
		if 1e-6 < rmse(dμ, Δμ) {
			XCTFail()
			print(dμ)
			print(Δμ)
		}
		
		if 1e-6 < rmse(dσ, Δσ) {
			XCTFail()
			print(dσ)
			print(Δσ)
		}
		
		let Δμk: [Float] = Δμ
		let Δσk: [Float] = Δσ.map { $0 * σ }
		
		GaussianDistribution.Δμ(Δ: LaMatrice(Δμ, rows: rows, cols: cols), μ: LaValuer(μ)).getBytes(Δμ)
		GaussianDistribution.Δσ(Δ: LaMatrice(Δσ, rows: rows, cols: cols), σ: LaValuer(σ)).getBytes(Δσ)
		
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
		let cols: Int = 4
		
		//		let η: Float = 0.5
		
		let μ: Float = -1.5
		let σ: Float =  0.25
		let λ: Float = 1 / σ
		
		let d: [Float] = uniform(rows*cols)
		
		let dχ: [Float] = d.map { sign($0) / ( 1 + μ * μ * λ * λ ) * Float(M_1_PI) }
		let dμ: [Float] = dχ.map { $0 * λ }
		let dσ: [Float] = dμ.map { $0 * -μ * λ }
		
		let Δχ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		let Δμ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		let Δσ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		
		CauchyDistribution.derivate((χ: UnsafeMutablePointer<Float>(Δχ), μ: UnsafeMutablePointer<Float>(Δμ), σ: UnsafeMutablePointer<Float>(Δσ)), δ: d, μ: [Float](count: rows*cols, repeatedValue: μ), λ: [Float](count: rows*cols, repeatedValue: λ), count: rows*cols)
		
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
		
		CauchyDistribution.Δμ(Δ: LaMatrice(Δμ, rows: rows, cols: cols), μ: LaValuer(μ)).getBytes(Δμ)
		CauchyDistribution.Δσ(Δ: LaMatrice(Δσ, rows: rows, cols: cols), σ: LaValuer(σ)).getBytes(Δσ)
		
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