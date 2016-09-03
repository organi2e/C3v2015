//
//  Cauchy.swift
//  C³
//
//  Created by Kota Nakano on 8/19/16.
//
//
import Accelerate
import CoreData
import simd

internal class CauchyDistribution: Distribution {
	static func cdf(χ: Float, μ: Float, σ: Float) -> Float {
		let level: Double = (Double(χ)-Double(μ))/Double(σ)
		return Float(
			0.5 + M_1_PI * atan(level)
		)
	}
	static func pdf(χ: Float, μ: Float, σ: Float) -> Float {
		let level: Double = (Double(χ)-Double(μ))/Double(σ)
		return Float(
			1.0 / ( M_PI * Double(σ) * ( 1.0 + level * level ) )
		)
	}
	//	static func cdf(χ: LaObjet, μ: LaObjet, σ: LaObjet) -> LaObjet
	//	static func pdf(χ: LaObjet, μ: LaObjet, σ: LaObjet) -> LaObjet
	static func rng(χ: [Float], ψ: [UInt32], μ: LaObjet, σ: LaObjet) {
		let count: Int = χ.count
		assert(μ.count==count)
		assert(σ.count==count)
		assert(ψ.count==count)
		vDSP_vfltu32(ψ, 1, UnsafeMutablePointer<Float>(χ), 1, vDSP_Length(count))
		vDSP_vsadd(χ, 1, [Float(0.5)], UnsafeMutablePointer<Float>(χ), 1, vDSP_Length(count))
		vDSP_vsdiv(χ, 1, [Float(UInt32.max)+1.0], UnsafeMutablePointer<Float>(χ), 1, vDSP_Length(count))
		vvtanpif(UnsafeMutablePointer<Float>(χ), χ, [Int32(count)])
		(LaMatrice(χ, rows: min(μ.rows, σ.rows), cols: min(μ.cols, σ.cols), deallocator: nil)*σ+μ).eval(χ)
	}
	static func derivate(Δχ Δχ: [Float], Δμ: [Float], Δσ: [Float], Δ delta: [Float], μ mu: [Float], λ lambda: [Float]) {
		let χ: LaObjet = LaMatrice(Δχ, rows: Δχ.count, cols: 1, deallocator: nil)
		let Δ: LaObjet = LaMatrice(delta, rows: delta.count, cols: 1, deallocator: nil)
		let μ: LaObjet = LaMatrice(mu, rows: mu.count, cols: 1, deallocator: nil)
		let λ: LaObjet = LaMatrice(lambda, rows: lambda.count, cols: 1, deallocator: nil)
		
		let λμ: LaObjet = λ * μ
		(1 + λμ * λμ).getBytes(Δχ)
		vvrecf(UnsafeMutablePointer<Float>(Δχ), Δχ, [Int32(Δχ.count)])
		
		(Float(M_1_PI)*Δ*χ).getBytes(Δχ)
		
		let λχ: LaObjet = λ * χ
		(λχ).getBytes(Δμ)
		(λχ*μ*λ).getBytes(Δσ)
		vDSP_vneg(Δσ, 1, UnsafeMutablePointer<Float>(Δσ), 1, vDSP_Length(Δσ.count))
	}
	static func gainχ(χ: LaObjet) -> (μ: LaObjet, σ: LaObjet) {
		return (χ, χ)
	}
	static func Δμ(Δ Δ: LaObjet, μ: LaObjet) -> LaObjet {
		return Δ
	}
	static func Δσ(Δ Δ: LaObjet, σ: LaObjet) -> LaObjet {
		return Δ
	}
	static func synthesize(χ χ: [Float], μ: [Float], λ: [Float], refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)]) {
		let mix: (χ: LaObjet, μ: LaObjet, λ: LaObjet) = refer.reduce((LaSplat(0), LaSplat(0), LaSplat(0))) {
			( $0.0.0 + $0.1.χ, $0.0.1 + $0.1.1, $0.0.2 + $0.1.σ )
		}
		mix.χ.getBytes(χ)
		mix.μ.getBytes(μ)
		mix.λ.getBytes(λ)
		vvrecf(UnsafeMutablePointer<Float>(λ), λ, [Int32(λ.count)])
	}
	static func est(χ: [Float], η: Float, K: Int, θ: Float = 1e-9) -> (μ: Float, σ: Float) {
		
		let count: Int = χ.count
		
		let eye: double2x2 = double2x2(diagonal: double2(1))
		
		var est: double2 = double2(1)
		var H: double2x2 = eye
		
		var p_est: double2 = est
		var p_delta: double2 = double2(0)

		let X: [Double] = [Double](count: count, repeatedValue: 0)
		let U: [Double] = [Double](count: count, repeatedValue: 0)
		let A: [Double] = [Double](count: count, repeatedValue: 0)
		let B: [Double] = [Double](count: count, repeatedValue: 0)
		let C: [Double] = [Double](count: count, repeatedValue: 0)
		
		vDSP_vspdp(χ, 1, UnsafeMutablePointer<Double>(X), 1, vDSP_Length(count))
		
		for _ in 0..<K {
			
			var mean: Double = 0
			
			vDSP_vsaddD(X, 1, [-est.x], UnsafeMutablePointer<Double>(U), 1, vDSP_Length(count))
			vDSP_vsqD(U, 1, UnsafeMutablePointer<Double>(B), 1, vDSP_Length(count))
			vDSP_vsaddD(B, 1, [est.y*est.y], UnsafeMutablePointer<Double>(B), 1, vDSP_Length(count))
			
			vDSP_vsmulD(U, 1, [2.0*est.x], UnsafeMutablePointer<Double>(A), 1, vDSP_Length(count))
			vDSP_vdivD(B, 1, A, 1, UnsafeMutablePointer<Double>(C), 1, vDSP_Length(count))
			vDSP_meanvD(C, 1, &mean, vDSP_Length(count))
			
			var delta: double2 = double2(0)
			
			delta.x = mean
			
			vDSP_svdivD([2.0*est.y], B, 1, UnsafeMutablePointer<Double>(C), 1, vDSP_Length(count))
			vDSP_meanvD(C, 1, &mean, vDSP_Length(count))
			
			delta.y = 1 / est.y - mean
			
			let s: double2 = est - p_est
			let y: double2 = delta - p_delta
			let m: Double = dot(y, s)
			if Double(θ) < abs(m) {//BFGS
				let rho: Double = 1.0 / m
				let S: double2x2 = double2x2([s, double2(0)])
				let Y: double2x2 = double2x2(rows: [y, double2(0)])
				let A: double2x2 = eye - rho * S * Y
				let B: double2x2 = A.transpose
				let C: double2x2 = S * S.transpose
				H = A * H * B + C
				delta = -H * delta
			}
			
			p_est = est
			p_delta = delta
			
			est = est + Double(η) * delta
			est = abs(est)
			
		}
		
		return (
			Float(est.x),
			Float(est.y)
		)
	}
}