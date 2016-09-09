//
//  GaussianTests.swift
//  Mac
//
//  Created by Kota Nakano on 8/29/16.
//
//
import XCTest
@testable import C3
class GaussianTests: XCTestCase {
	
	let context: Context = try!Context()
	
	let posi: Float = 1
	let nega: Float = -1
	let zero: Float = 0
	
	func uniform(count: Int) -> [Float] {
		return(0..<count).map {(_)in
			Float(arc4random())/Float(arc4random())
		}
	}
	
	func rmse( x: [Float], _ y: [Float]) -> Float {
		let err: [Float] = zip(x, y).map { $0.0 - $0.1 }
		let se: [Float] = err.map { $0 * $0 }
		let mse: Float = se.reduce(0) { $0.0 + $0.1 }
		let rmse: Float = sqrt(mse / Float(se.count))
		return rmse
	}
	/*
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
	*/
	
	func testCDF() {
		
		let distribution: Distribution = try!GaussianDistribution(context: context)
		let N: Int = 16
		
		let λd: [Float] = uniform(N)
		let μd: [Float] = uniform(N).map { $0 * 2 - 1 }
		let χd: [Float] = zip(μd, λd).map { 0.5 * ( 1 + erf( $0.0 * $0.1 * Float(M_SQRT1_2) ) ) }
		
		let λ: Buffer = context.newBuffer(λd)
		let μ: Buffer = context.newBuffer(μd)
		let χ: Buffer = context.newBuffer(length: sizeof(Float)*N)
		
		let command: Command = context.newCommand()
		let compute: Compute = command.computeCommandEncoder()
		
		distribution.cdf(compute, χ: χ, μ: μ, λ: λ)
		
		compute.endEncoding()
		command.commit()
		command.waitUntilCompleted()
		
		let rmseχ: Float = rmse(χd, χ.vecteur.array)
		if 1e-7 < rmseχ {
			print(χd)
			print(χ.vecteur.array)
			XCTFail()
		}
		
	}
	
	func testPDF() {
		
		let distribution: Distribution = try!GaussianDistribution(context: context)
		let N: Int = 16
		
		let λd: [Float] = uniform(N)
		let μd: [Float] = uniform(N) .map { $0 * 2 - 1 }
		let χd: [Float] = zip(μd, λd) .map { $0.1 * exp( -0.5 * $0.0 * $0.0 * $0.1 * $0.1 ) / sqrt( 2.0 * Float ( M_PI ) ) }
		
		let λ: Buffer = context.newBuffer(λd)
		let μ: Buffer = context.newBuffer(μd)
		let χ: Buffer = context.newBuffer(length: sizeof(Float)*N)
		
		let command: Command = context.newCommand()
		let compute: Compute = command.computeCommandEncoder()
		
		distribution.pdf(compute, χ: χ, μ: μ, λ: λ)
		
		compute.endEncoding()
		command.commit()
		command.waitUntilCompleted()
		
		
		let rmseχ: Float = rmse(χd, χ.vecteur.array)
		if 1e-7 < rmseχ {
			print(χd)
			print(χ.vecteur.array)
			XCTFail()
		}
	}
	
	func testΔ() {
		
		let distr: GaussianDistribution = try!GaussianDistribution(context: context)
		
		let Δd: [Float] = Array<Float>(arrayLiteral: 2, 3, 5, 7)
		let Δ: LaObjet = LaMatrice(Δd, rows: Δd.count, cols: 1)
		
		let μd: [Float] = Array<Float>(arrayLiteral: 1, 1, 2, 3)
		let μ: LaObjet = LaMatrice(μd, rows: μd.count, cols: 1)
		
		let σd: [Float] = Array<Float>(arrayLiteral: 1, 2, 4, 8)
		let σ: LaObjet = LaMatrice(σd, rows: σd.count, cols: 1)
		
		let Δμ: LaObjet = distr.Δμ(Δ: Δ, μ: μ)
		let Δσ: LaObjet = distr.Δσ(Δ: Δ, σ: σ)
		
		print(Δμ.array)
		print(Δσ.array)
		
		//XCTAssert(Δσ.array.elementsEqual(zip(Δ, σ).map { 2 * $0 * $1 * $1 }))
		
	}
	
	func testGain() {
		
		let distr: GaussianDistribution = try!GaussianDistribution(context: context)
		
		let χd: [Float] = Array<Float>(arrayLiteral: 0, 1, 2, 3)
		let χ: Buffer = context.newBuffer(χd)
		
		let weight = distr.gainχ(χ.vecteur)
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
		
		var μd: [Float] = [Float](count: N, repeatedValue: 0.0)
		var λd: [Float] = [Float](count: N, repeatedValue: 0.0)
		var χd: [Float] = [Float](count: N, repeatedValue: 0.0)
		
		let μ: Buffer = context.newBuffer(μd)
		let λ: Buffer = context.newBuffer(λd)
		let χ: Buffer = context.newBuffer(χd)
		
		let distr: GaussianDistribution = try!GaussianDistribution(context: context)
		distr.synthesize(χ: χ, μ: μ, λ: λ, refer: refer)
		
		for l in 0..<L {
			for n in 0..<N {
				χd[l] = χd[l] + refer[n].χ.array[l]
				μd[l] = μd[l] + refer[n].μ.array[l]
				λd[l] = λd[l] + ( refer[n].σ.array[l] * refer[n].σ.array[l] )
			}
			λd[l] = 1 / sqrt(λd[l])
		}
		
		XCTAssert((LaMatrice(χd, rows: L, cols: 1, deallocator: nil) - χ.vecteur).length < 1e-7)
		XCTAssert((LaMatrice(μd, rows: L, cols: 1, deallocator: nil) - μ.vecteur).length < 1e-7)
		XCTAssert((LaMatrice(λd, rows: L, cols: 1, deallocator: nil) - λ.vecteur).length < 1e-7)

	}
	
    func testRNG() {

		let distr: GaussianDistribution = try!GaussianDistribution(context: context)
		
		let srcμ: Float = Float(arc4random())/Float(UInt32.max) * 2.0 - 1.0
		let srcσ: Float = 1.0 + Float(M_PI) * Float(arc4random()) / Float( UInt32.max )

		let N: Int = 8192
		let μd: [Float] = [Float](count: N, repeatedValue: srcμ)
		let σd: [Float] = [Float](count: N, repeatedValue: srcσ)
		let χd: [Float] = [Float](count: N, repeatedValue: 0.0)
		
		let μ: Buffer = context.newBuffer(μd)
		let σ: Buffer = context.newBuffer(σd)
		let χ: Buffer = context.newBuffer(χd)
		
		let command: Command = context.newCommand()
		let compute: Compute = command.computeCommandEncoder()
		
		distr.rng(compute, χ: χ, μ: μ, σ: σ)
		
		compute.endEncoding()
		command.commit()
		command.waitUntilCompleted()
		
		let (dstμ, dstσ) = distr.est(χ)
		
		let rmseμ: Float = ( srcμ - dstμ ) * ( srcμ - dstμ )
		let rmseσ: Float = ( srcσ - dstσ ) * ( srcσ - dstσ )
		
		if 1e-3 < rmseμ {
			print(srcμ, dstμ)
			XCTFail()
		}
		if 1e-3 < rmseσ {
			print(srcσ, dstσ)
			XCTFail()
		}
    }
}
