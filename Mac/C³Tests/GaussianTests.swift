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
	
	func uniform(count: Int) -> [Float] {
		return(0..<count).map {(_)in
			Float(arc4random())/Float(arc4random())
		}
	}
	
	func testActivate() {
		let X: [Float] = uniform(512) + [Float](count: 512, repeatedValue: 0)
		let Y: [Float] = X.map { 0 < $0 ? 1 : 0 }
		let Z: [Float] = X.map { (_)in 0.0 }
		
		GaussianDistribution.activate(UnsafeMutablePointer<Float>(Z), φ: X, count: X.count)
		
		XCTAssert(Z.elementsEqual(Y))
	}
	
	func testDerivatevDSP() {
		
		let N: Int = 16
		
		let Δ: [Float] = uniform(N)
		let μ: [Float] = uniform(N)
		let λ: [Float] = uniform(N)
		
		func error(x: Float) -> Float {
			return 0 < x ? 1 : x < 0 ? -1 : 0
		}
		func gauss(μ μ: Float, λ: Float) -> Float {
			return exp(-0.5*μ*μ*λ*λ)/Float(sqrt(2.0*M_PI))
		}
		let Δχ_src: [Float] = Δ.enumerate().map { error($0.element) * gauss(μ: μ[$0.index], λ: λ[$0.index]) }
		let Δμ_src: [Float] = Δχ_src.enumerate().map { $0.element * λ[$0.index] }
		let Δσ_src: [Float] = Δχ_src.enumerate().map { $0.element * λ[$0.index] * λ[$0.index] * λ[$0.index] * -μ[$0.index] }
		
		let Δχ_dst: [Float] = [Float](count: N, repeatedValue: 0)
		let Δμ_dst: [Float] = [Float](count: N, repeatedValue: 0)
		let Δσ_dst: [Float] = [Float](count: N, repeatedValue: 0)
		
		GaussianDistribution.derivate((χ: UnsafeMutablePointer<Float>(Δχ_dst), μ: UnsafeMutablePointer<Float>(Δμ_dst), σ: UnsafeMutablePointer<Float>(Δσ_dst)), δ: Δ, μ: μ, λ: λ, count: N)
		
		let rmseΔχ: Float = zip(Δχ_src, Δχ_dst).map { $0.0 - $0.1 }.map { $0 * $0 }.reduce(0) { $0.0 + $0.1 }
		if 1e-9 < rmseΔχ {
			XCTFail("rmseΔχ: \(rmseΔχ)")
			print(Δχ_src)
			print(Δχ_dst)
		}
		
		let rmseΔμ: Float = zip(Δμ_src, Δμ_dst).map { $0.0 - $0.1 }.map { $0 * $0 }.reduce(0) { $0.0 + $0.1 }
		if 1e-9 < rmseΔμ {
			XCTFail("rmseΔμ: \(rmseΔμ)")
			print(Δμ_src)
			print(Δμ_dst)
		}
		
		let rmseΔσ: Float = zip(Δσ_src, Δσ_dst).map { $0.0 - $0.1 }.map { $0 * $0 }.reduce(0) { $0.0 + $0.1 }
		if 1e-9 < rmseΔσ {
			XCTFail("rmseΔσ: \(rmseΔσ)")
			print(Δσ_src)
			print(Δσ_dst)
		}
		
	}
	/*
	func testDerivate2() {
		
		let N: Int = 16
		
		let X: [Float] = [Float](count: N, repeatedValue: 0)
		
		UnsafeMutablePointer<Float>(X)[0] = -1
		UnsafeMutablePointer<Float>(X)[1] = -0.5
		UnsafeMutablePointer<Float>(X)[2] = -0.0
		UnsafeMutablePointer<Float>(X)[3] = 0.5
		UnsafeMutablePointer<Float>(X)[4] = 1.0
		UnsafeMutablePointer<Float>(X)[5] = 0.5
		UnsafeMutablePointer<Float>(X)[6] = 0.0
		UnsafeMutablePointer<Float>(X)[7] = -0.5
		
		let Y: [Float] = X.map { 0 < $0 ? 1 : 0 }
		let Z: [Float] = X.map { 1 - vector_step(0, -$0) }
		let W: [Float] = [Float](count: N, repeatedValue: 0)
		
		print(X)
		/*sign
		vDSP_vneg(X, 1, UnsafeMutablePointer<Float>(W), 1, vDSP_Length(N))
		vDSP_vlim(X, 1, [Float(0.0)], [Float( 0.5)], UnsafeMutablePointer<Float>(X), 1, vDSP_Length(N))
		vDSP_vlim(W, 1, [Float(0.0)], [Float(-0.5)], UnsafeMutablePointer<Float>(W), 1, vDSP_Length(N))
		vDSP_vadd(X, 1, W, 1, UnsafeMutablePointer<Float>(X), 1, vDSP_Length(N))
		*/
		
		//step
		
		vDSP_vneg(X, 1, UnsafeMutablePointer<Float>(X), 1, vDSP_Length(N))
		//vDSP_vlim(X, 1, [Float(0.0)], [Float( 0.5)], UnsafeMutablePointer<Float>(X), 1, vDSP_Length(N))
		vDSP_vthrsc(X, 1, [Float(0.0)], [Float( 0.5)], UnsafeMutablePointer<Float>(X), 1, vDSP_Length(N))
		//vDSP_vlim(W, 1, [Float(0.0)], [Float(-0.5)], UnsafeMutablePointer<Float>(W), 1, vDSP_Length(N))
		//vDSP_vadd(X, 1, W, 1, UnsafeMutablePointer<Float>(X), 1, vDSP_Length(N))
		vDSP_vsmsa(X, 1, [-Float(1.0)], [Float(0.5)], UnsafeMutablePointer<Float>(X), 1, vDSP_Length(N))
		
		print(X)
		print(Y)
		print(Z)
		
		XCTAssert(Y.elementsEqual(Z))
		
	}
	*/
	/*
	func testDerivate() {
		
		let L: Int = 16
		
		let Δχ: [Float] = uniform(L)
		let Δμ: [Float] = uniform(L)
		let Δσ: [Float] = uniform(L)
		let Δ: [Float] = uniform(L)
		let μ: [Float] = uniform(L)
		let λ: [Float] = uniform(L)
		
		var dΔχ: [Float] = [Float](count: L, repeatedValue: 0)
		var dΔμ: [Float] = [Float](count: L, repeatedValue: 0)
		var dΔσ: [Float] = [Float](count: L, repeatedValue: 0)
		
		GaussianDistribution.derivate(Δχ: Δχ, Δμ: Δμ, Δσ: Δσ, Δ: Δ, μ: μ, λ: λ)
		
		for k in 0..<L {
			let λd: Double = Double(λ[k])
			let μd: Double = Double(μ[k])
			let Δd: Double = Double(Δ[k])
			let dΔχd = Δd * exp( -0.5 * λd * λd * μd * μd ) / sqrt( 2 * M_PI )
			dΔχ[k] = Float(dΔχd)
			dΔμ[k] = Float(dΔχd * λd)
			dΔσ[k] = Float(dΔχd * λd * 0.5 * -μd * λd * λd)
		}
		
		if 1e-7 < (LaMatrice(dΔχ, rows: L, cols: 1, deallocator: nil) - LaMatrice(Δχ, rows: L, cols: 1, deallocator: nil)).length / Float(L) {
			print("χ", dΔχ, "\r\n", Δχ)
			XCTFail()
		}

		if 1e-7 < (LaMatrice(dΔμ, rows: L, cols: 1, deallocator: nil) - LaMatrice(Δμ, rows: L, cols: 1, deallocator: nil)).length / Float(L) {
			print("μ", dΔμ, "\r\n", Δμ)
			XCTFail()
		}

		if 1e-7 < (LaMatrice(dΔσ, rows: L, cols: 1, deallocator: nil) - LaMatrice(Δσ, rows: L, cols: 1, deallocator: nil)).length / Float(L) {
			print("σ", dΔσ, "\r\n", Δσ)
			XCTFail()
		}
	
	}
	*/
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
		
		GaussianDistribution.synthesize(χ: χ, μ: μ, λ: λ, refer: refer, count: L)
		
		for l in 0..<L {
			for n in 0..<N {
				χd[l] = χd[l] + refer[n].χ.array[l]
				μd[l] = μd[l] + refer[n].μ.array[l]
				λd[l] = λd[l] + (refer[n].σ.array[l]*refer[n].σ.array[l])
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
		//GaussianDistribution.rng(χ, ψ: ψ, μ: LaMatrice(μ, rows: 1024, cols: 1024, deallocator: nil), σ: LaMatrice(σ, rows: 1024, cols: 1024, deallocator: nil))
		
		let(dstμ, dstσ) = GaussianDistribution.est(χ)
		
		print(srcμ, dstμ)
		print(srcσ, dstσ)
		
		let rmseμ: Float = ( srcμ - dstμ ) * ( srcμ - dstμ )
		let rmseσ: Float = ( srcσ - dstσ ) * ( srcσ - dstσ )
		XCTAssert(rmseμ < 1e-3)
		XCTAssert(rmseσ < 1e-3)
    }

}
