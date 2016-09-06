//
//  GaussianTests.swift
//  Mac
//
//  Created by Kota Nakano on 8/29/16.
//
//
import Accelerate
import simd
import XCTest
@testable import C3
class GaussianTests: XCTestCase {
	
	let posi: Float = 1
	let nega: Float = -1
	let zero: Float = 0
	
	func uniform(count: Int) -> [Float] {
		return(0..<count).map {(_)in
			Float(arc4random())/Float(arc4random())
		}
	}
	
	func testActivate() {
		let X: [Float] = uniform(512) + [Float](count: 512, repeatedValue: 0)
		let Y: [Float] = X.map { zero < $0 ? posi : zero }
		let Z: [Float] = X.map { (_)in zero }
		
		GaussianDistribution.activate(UnsafeMutablePointer<Float>(Z), φ: X, count: X.count)
		
		XCTAssert(Z.elementsEqual(Y))
	}
	
	func rmse(x: [Float], _ y: [Float]) -> Float {
		let err: [Float] = zip(x, y).map { $0.0 - $0.1 }
		let se: [Float] = err.map { $0 * $0 }
		let mse: Float = se.reduce(0) { $0.0 + $0.1 }
		let rmse: Float = sqrt(mse / Float(se.count))
		return rmse
	}
	
	func testDerivatevDSP() {
		
		let N: Int = 16
		
		let Δ: [Float] = uniform(N)
		let μ: [Float] = uniform(N)
		let λ: [Float] = uniform(N)
		
		func error(x: Float) -> Float {
			return zero < x ? posi : x < zero ? nega : zero
		}
		func gauss(μ μ: Float, λ: Float) -> Float {
			return exp(Float(-0.5)*μ*μ*λ*λ)/sqrt(Float(2.0)*Float(M_PI))
		}
		let Δχ_src: [Float] = (0..<N).map {
			error(Δ[$0]) * gauss(μ: μ[$0], λ: λ[$0])
		}
		let Δμ_src: [Float] = (0..<N).map {
			Δχ_src[$0] * λ[$0]
		}
		let Δσ_src: [Float] = (0..<N).map {
			Δμ_src[$0] * λ[$0] * -μ[$0] * λ[$0]
		}
		
		let Δχ_dst: [Float] = [Float](count: N, repeatedValue: 0)
		let Δμ_dst: [Float] = [Float](count: N, repeatedValue: 0)
		let Δσ_dst: [Float] = [Float](count: N, repeatedValue: 0)
		
		GaussianDistribution.derivate((χ: UnsafeMutablePointer<Float>(Δχ_dst), μ: UnsafeMutablePointer<Float>(Δμ_dst), σ: UnsafeMutablePointer<Float>(Δσ_dst)), δ: Δ, μ: μ, λ: λ, count: N)
		
		let rmseΔχ: Float = rmse(Δχ_src, Δχ_dst)
		if 1e-5 < rmseΔχ {
			XCTFail("rmseΔχ: \(rmseΔχ)")
			print(Δχ_src)
			print(Δχ_dst)
		}
		
		let rmseΔμ: Float = rmse(Δμ_src, Δμ_dst)
		if 1e-5 < rmseΔμ {
			XCTFail("rmseΔμ: \(rmseΔμ)")
			print(Δμ_src)
			print(Δμ_dst)
		}
		
		let rmseΔσ: Float = rmse(Δσ_src, Δσ_dst)
		if 1e-5 < rmseΔσ {
			XCTFail("rmseΔσ: \(rmseΔσ)")
			print(Δσ_src)
			print(Δσ_dst)
		}
		
	}
	func testΔ() {
		
		let Δd: [Float] = Array<Float>(arrayLiteral: 0, 1, 2, 3)
		let Δ: LaObjet = LaMatrice(Δd, rows: Δd.count, cols: 1)
		
		let μd: [Float] = Array<Float>(arrayLiteral: 0, 1, 2, 3)
		let μ: LaObjet = LaMatrice(μd, rows: μd.count, cols: 1)
		
		let σd: [Float] = Array<Float>(arrayLiteral: 0, 1, 2, 3)
		let σ: LaObjet = LaMatrice(σd, rows: σd.count, cols: 1)
		
		let Δμ: LaObjet = GaussianDistribution.Δμ(Δ: Δ, μ: μ)
		let Δσ: LaObjet = GaussianDistribution.Δσ(Δ: Δ, σ: σ)
		
		XCTAssert(Δ.array.elementsEqual(Δμ.array))
		XCTAssert(zip(Δ.array, σ.array).map { $0 * $1 }.elementsEqual(Δσ.array))
		
		
		//XCTAssert(Δσ.array.elementsEqual(zip(Δ, σ).map { 2 * $0 * $1 * $1 }))
		
	}
	
	func testGain() {
		let χd: [Float] = Array<Float>(arrayLiteral: 0, 1, 2, 3)
		let χ: LaObjet = LaMatrice(χd, rows: χd.count, cols: 1)
		
		let weight = GaussianDistribution.gainχ(χ)
		XCTAssert(weight.0.array.elementsEqual(χd))
		XCTAssert(weight.1.array.elementsEqual(χd.map { $0 * $0 }))
	}
	
	func testSynthesize() {
		let N: Int = 16
		let L: Int = 16
		var refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)] = []
		for _ in 0..<N {
			let element: (χ: LaObjet, μ: LaObjet, σ: LaObjet) = (
				LaMatrice(uniform(L), rows: L, cols: 1),
				LaMatrice(uniform(L), rows: L, cols: 1),
				LaMatrice(uniform(L), rows: L, cols: 1)
			)
			refer.append(element)
		}
		let χ: [Float] = [Float](count: L, repeatedValue: 0)
		let μ: [Float] = [Float](count: L, repeatedValue: 0)
		let λ: [Float] = [Float](count: L, repeatedValue: 0)
		
		var χd: [Float] = [Float](count: L, repeatedValue: 0)
		var μd: [Float] = [Float](count: L, repeatedValue: 0)
		var λd: [Float] = [Float](count: L, repeatedValue: 0)
		
		GaussianDistribution.synthesize(χ: UnsafeMutablePointer<Float>(χ), μ: UnsafeMutablePointer<Float>(μ), λ: UnsafeMutablePointer<Float>(λ), refer: refer, count: L)
		
		for l in 0..<L {
			for n in 0..<N {
				χd[l] = χd[l] + refer[n].χ.array[l]
				μd[l] = μd[l] + refer[n].μ.array[l]
				λd[l] = λd[l] + ( refer[n].σ.array[l] * refer[n].σ.array[l] )
			}
			λd[l] = rsqrt(λd[l])
		}
		XCTAssert((LaMatrice(χd, rows: L, cols: 1, deallocator: nil) - LaMatrice(χ, rows: L, cols: 1, deallocator: nil)).length<1e-7)
		XCTAssert((LaMatrice(μd, rows: L, cols: 1, deallocator: nil) - LaMatrice(μ, rows: L, cols: 1, deallocator: nil)).length<1e-7)
		XCTAssert((LaMatrice(λd, rows: L, cols: 1, deallocator: nil) - LaMatrice(λ, rows: L, cols: 1, deallocator: nil)).length<1e-7)

	}
	
    func testRNG() {

		let srcμ: Float = Float(arc4random())/Float(UInt32.max) * 2.0 - 1.0
		let srcσ: Float = 1.0 + Float(M_PI) * Float(arc4random())/Float(UInt32.max)

		let N: Int = 1024 * 1024
		let ψ: [UInt32] = [UInt32](count: N, repeatedValue: 0)
		let μ: [Float] = [Float](count: N, repeatedValue: srcμ)
		let σ: [Float] = [Float](count: N, repeatedValue: srcσ)
		let χ: [Float] = [Float](count: N, repeatedValue: 0.0)
		
		arc4random_buf(UnsafeMutablePointer<Void>(ψ), sizeof(UInt32)*N)
		
		GaussianDistribution.rng(UnsafeMutablePointer<Float>(χ), ψ: ψ, μ: μ, σ: σ, count: N)
		
		let(dstμ, dstσ) = GaussianDistribution.est(χ)
		
		print(srcμ, dstμ)
		print(srcσ, dstσ)
		
		let rmseμ: Float = ( srcμ - dstμ ) * ( srcμ - dstμ )
		let rmseσ: Float = ( srcσ - dstσ ) * ( srcσ - dstσ )
		XCTAssert(rmseμ < 1e-3)
		XCTAssert(rmseσ < 1e-3)
    }
}
