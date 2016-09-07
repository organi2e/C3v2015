//
//  GaussianTests.swift
//  Mac
//
//  Created by Kota Nakano on 8/29/16.
//
//
import Accelerate
import XCTest
@testable import C3
class CauchyTests: XCTestCase {
	
	func rmse(x: [Float], _ y: [Float]) -> Float {
		let err: [Float] = zip(x, y).map { $0.0 - $0.1 }
		let se: [Float] = err.map { $0 * $0 }
		let mse: Float = se.reduce(0) { $0.0 + $0.1 }
		let rmse: Float = sqrt(mse / Float(se.count))
		return rmse
	}
	
	func uniform(count: Int, a: Float, b: Float) -> [Float] {
		return(0..<count).map {(_)in
			a * Float(arc4random())/Float(arc4random()) + b
		}
	}
	
	func testActivate() {
		
		let N: Int = 16
		let x: [Float] = uniform(N - 2, a: 2.0, b: -1.0) + [0, -0]
		let y: [Float] = uniform(N, a: 2.0, b: -1.0)
		let z: [Float] = x.map { 0 < $0 ? 1 : 0 }
		
		CauchyDistribution.activate(UnsafeMutablePointer<Float>(y), φ: x, count: N)
		
		if !y.elementsEqual(z) {
			print(y)
			print(z)
			XCTFail()
		}
		
	}
	
	func testDerivate() {
		
		let N: Int = 32
		
		let Δ: [Float] = uniform(N-2, a: 2.0, b: -1.0) + [0, 0]
		let μ: [Float] = uniform(N, a: 2.0, b: -1.0)
		let λ: [Float] = uniform(N, a: 1.0, b: 0.0)
		
		func error(x: Float) -> Float {
			return 0 < x ? 1 : x < 0 ? -1 : 0
		}
		func cauchy(μ μ: Float, λ: Float) -> Float {
			return Float(M_1_PI)/(1+μ*μ*λ*λ)
		}
		let Δχ_src: [Float] = Δ.enumerate().map { error($0.element) * cauchy(μ: μ[$0.index], λ: λ[$0.index]) }
		let Δμ_src: [Float] = Δχ_src.enumerate().map { $0.element * λ[$0.index] }
		let Δσ_src: [Float] = Δχ_src.enumerate().map { $0.element * λ[$0.index] * λ[$0.index] * -μ[$0.index] }
		
		let Δχ_dst: [Float] = [Float](count: N, repeatedValue: 0)
		let Δμ_dst: [Float] = [Float](count: N, repeatedValue: 0)
		let Δσ_dst: [Float] = [Float](count: N, repeatedValue: 0)
		
		CauchyDistribution.derivate((χ: UnsafeMutablePointer<Float>(Δχ_dst), μ: UnsafeMutablePointer<Float>(Δμ_dst), σ: UnsafeMutablePointer<Float>(Δσ_dst)), δ: Δ, μ: μ, λ: λ, count: N)
		
		let rmseΔχ: Float = rmse(Δχ_src, Δχ_dst)
		if 1e-7 < rmseΔχ {
			XCTFail("rmseΔχ: \(rmseΔχ)")
			print(Δχ_src)
			print(Δχ_dst)
		}
		
		let rmseΔμ: Float = rmse(Δμ_src, Δμ_dst)
		if 1e-7 < rmseΔμ || isnan(rmseΔμ) || isinf(rmseΔμ) {
			XCTFail("rmseΔμ: \(rmseΔμ)")
			print(Δμ_src)
			print(Δμ_dst)
		}
		
		let rmseΔσ: Float = rmse(Δσ_src, Δσ_dst)
		if 1e-7 < rmseΔσ || isnan(rmseΔσ) || isinf(rmseΔσ) {
			XCTFail("rmseΔσ: \(rmseΔσ)")
			print(Δσ_src)
			print(Δσ_dst)
		}
		
	}
	/*
	func testDerivate() {
		
		let L: Int = 64
		
		let Δχ: [Float] = uniform(L)
		let Δμ: [Float] = uniform(L)
		let Δσ: [Float] = uniform(L)
		let Δ: [Float] = uniform(L)
		let μ: [Float] = uniform(L)
		let λ: [Float] = uniform(L)
		
		var dΔχ: [Float] = [Float](count: L, repeatedValue: 0)
		var dΔμ: [Float] = [Float](count: L, repeatedValue: 0)
		var dΔσ: [Float] = [Float](count: L, repeatedValue: 0)
		
		CauchyDistribution.derivate(Δχ: Δχ, Δμ: Δμ, Δσ: Δσ, Δ: Δ, μ: μ, λ: λ)
		
		for k in 0..<L {
			let λd: Double = Double(λ[k])
			let μd: Double = Double(μ[k])
			let Δd: Double = Double(Δ[k])
			let dΔχd = ( Δd / ( 1 + ( λd * λd * μd * μd ) ) ) / M_PI
			dΔχ[k] = Float(dΔχd)
			dΔμ[k] = Float(dΔχd * λd)
			dΔσ[k] = Float(dΔχd * λd * -μd * λd)
		}
		
		if 1e-6 < (LaMatrice(dΔχ, rows: L, cols: 1, deallocator: nil) - LaMatrice(Δχ, rows: L, cols: 1, deallocator: nil)).length {
			print("χ", dΔχ, "\r\n", Δχ)
			XCTFail()
		}
		
		if 1e-6 < (LaMatrice(dΔμ, rows: L, cols: 1, deallocator: nil) - LaMatrice(Δμ, rows: L, cols: 1, deallocator: nil)).length {
			print("μ", dΔμ, "\r\n", Δμ)
			XCTFail()
		}
		
		if 1e-6 < (LaMatrice(dΔσ, rows: L, cols: 1, deallocator: nil) - LaMatrice(Δσ, rows: L, cols: 1, deallocator: nil)).length {
			print("σ", dΔσ, "\r\n", Δσ)
			XCTFail()
		}
		
	}
	*/
	func testΔ() {
		
		let Δd: [Float] = Array<Float>(arrayLiteral: 0, 1, 2, 4)
		let Δ: LaObjet = LaMatrice(Δd, rows: Δd.count, cols: 1)
		
		let μd: [Float] = Array<Float>(arrayLiteral: 1, 1, 2, 3)
		let μ: LaObjet = LaMatrice(μd, rows: μd.count, cols: 1)
		
		let σd: [Float] = Array<Float>(arrayLiteral: 2, 3, 5, 7)
		let σ: LaObjet = LaMatrice(σd, rows: σd.count, cols: 1)
		
		let Δμ: LaObjet = CauchyDistribution.Δμ(Δ: Δ, μ: μ)
		let Δσ: LaObjet = CauchyDistribution.Δσ(Δ: Δ, σ: σ)
		
		XCTAssert(Δμ.array.elementsEqual(Δ.array))
		XCTAssert(Δσ.array.elementsEqual(Δ.array))
		
	}
	
	func testGain() {
		let χd: [Float] = Array<Float>(arrayLiteral: 0, 1, 2, 3)
		let χ: LaObjet = LaMatrice(χd, rows: χd.count, cols: 1)
		
		let weight = CauchyDistribution.gainχ(χ)
		XCTAssert(weight.0.array.elementsEqual(χd))
		XCTAssert(weight.1.array.elementsEqual(χd))
	}
	
	func testSynthesize() {
		let N: Int = 4
		let L: Int = 16
		var refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)] = []
		for _ in 0..<N {
			let element: (χ: LaObjet, μ: LaObjet, σ: LaObjet) = (
				LaMatrice(uniform(L, a: 2, b: -1), rows: L, cols: 1),
				LaMatrice(uniform(L, a: 1, b: 0), rows: L, cols: 1),
				LaMatrice(uniform(L, a: 2, b: -1), rows: L, cols: 1)
			)
			refer.append(element)
		}
		let χ: [Float] = [Float](count: L, repeatedValue: 0)
		let μ: [Float] = [Float](count: L, repeatedValue: 0)
		let λ: [Float] = [Float](count: L, repeatedValue: 0)
		
		var χd: [Float] = [Float](count: L, repeatedValue: 0)
		var μd: [Float] = [Float](count: L, repeatedValue: 0)
		var λd: [Float] = [Float](count: L, repeatedValue: 0)
		
		CauchyDistribution.synthesize(χ: UnsafeMutablePointer<Float>(χ), μ: UnsafeMutablePointer<Float>(μ), λ: UnsafeMutablePointer<Float>(λ), refer: refer, count: L)
		
		for l in 0..<L {
			for n in 0..<N {
				χd[l] = χd[l] + refer[n].χ.array[l]
				μd[l] = μd[l] + refer[n].μ.array[l]
				λd[l] = λd[l] + refer[n].σ.array[l]
			}
			λd[l] = 1 / λd[l]
		}
		if 1e-9 < (LaMatrice(χd, rows: L, cols: 1, deallocator: nil) - LaMatrice(χ, rows: L, cols: 1, deallocator: nil)).L2Norm {
			print(χd, χ)
			XCTFail()
		}
		if 1e-9 < (LaMatrice(μd, rows: L, cols: 1, deallocator: nil) - LaMatrice(μ, rows: L, cols: 1, deallocator: nil)).L2Norm {
			print(μd, μ)
			XCTFail()
		}
		if 1e-9 < (LaMatrice(λd, rows: L, cols: 1, deallocator: nil) - LaMatrice(λ, rows: L, cols: 1, deallocator: nil)).L2Norm {
			print(λd)
			print(λ)
			XCTFail()
		}
		
	}
	
	
	func testRNG() {
		
		let srcμ: Float = Float(arc4random())/Float(UInt32.max) * 2.0 - 1.0
		let srcσ: Float = 1.0 + Float(M_PI) * Float(arc4random())/Float(UInt32.max)
		
		let rows: Int = 256
		let cols: Int = 256
		let ψ: [UInt32] = [UInt32](count: rows*cols, repeatedValue: 0)
		let μ: [Float] = [Float](count: rows*cols, repeatedValue: srcμ)
		let σ: [Float] = [Float](count: rows*cols, repeatedValue: srcσ)
		let χ: [Float] = [Float](count: rows*cols, repeatedValue: 0.0)
		
		arc4random_buf(UnsafeMutablePointer<Void>(ψ), sizeof(UInt32)*rows*cols)
		
		CauchyDistribution.rng(UnsafeMutablePointer<Float>(χ), ψ: ψ, μ: μ, σ: σ, count: rows*cols)
		//CauchyDistribution.rng(χ, ψ: ψ, μ: LaMatrice(μ, rows: rows, cols: cols, deallocator: nil), σ: LaMatrice(σ, rows: rows, cols: cols, deallocator: nil))
		
		let(dstμ, dstσ) = CauchyDistribution.est(χ, η: 0.8, K: 1024)
		
		print(srcμ, dstμ)
		print(srcσ, dstσ)
		
		let rmseμ: Float = ( srcμ - dstμ ) * ( srcμ - dstμ )
		let rmseσ: Float = ( srcσ - dstσ ) * ( srcσ - dstσ )
		
		XCTAssert(!isinf(rmseμ))
		XCTAssert(!isnan(rmseμ))
		XCTAssert(!isinf(rmseσ))
		XCTAssert(!isnan(rmseσ))
		
		XCTAssert(rmseμ < 1e-1)
		XCTAssert(rmseσ < 1e-1)
		
	}
	
}
