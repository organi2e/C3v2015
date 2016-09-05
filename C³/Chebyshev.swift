//
//  ChebyshevDistribution.swift
//  Mac
//
//  Created by Kota Nakano on 9/5/16.
//
//
import Accelerate
import CoreData
import simd

internal class ChebyshevDistribution: Distribution {
	static func cdf(χ: Float, μ: Float, σ: Float) -> Float {
		let level: Double = (Double(χ)-Double(μ))/Double(σ)
		return Float(
			0.0
		)
	}
	static func pdf(χ: Float, μ: Float, σ: Float) -> Float {
		let level: Double = (Double(χ)-Double(μ))/Double(σ)
		return Float(
			( level == 0 ? 1.0 : sin(level) / level ) / Double(σ) / M_PI
		)
	}
	//	static func cdf(χ: LaObjet, μ: LaObjet, σ: LaObjet) -> LaObjet
	//	static func pdf(χ: LaObjet, μ: LaObjet, σ: LaObjet) -> LaObjet
	static func rng(χ: [Float], ψ: [UInt32], μ: LaObjet, σ: LaObjet) {
		let count: Int = χ.count
		assert(μ.count==count)
		assert(σ.count==count)
		assert(ψ.count==count)
	}
	static func activate(κ: UnsafeMutablePointer<Float>, φ: UnsafePointer<Float>, count: Int) {
		let κref: UnsafeMutablePointer<float4> = UnsafeMutablePointer<float4>(κ)
		let φref: UnsafePointer<float4> = UnsafePointer<float4>(φ)
		(0..<count/4).forEach {
			κref[$0] = vector_step(float4(0.0), φref[$0])
		}
	}
	static func derivate(Δ: (χ: UnsafeMutablePointer<Float>, μ: UnsafeMutablePointer<Float>, σ: UnsafeMutablePointer<Float>), δ: UnsafePointer<Float>, μ: UnsafePointer<Float>, λ: UnsafePointer<Float>, count: Int) {
		cblas_scopy(Int32(count), δ, 1, Δ.χ, 1)
		cblas_scopy(Int32(count), δ, 1, Δ.μ, 1)
	}
	static func derivate(Δχ Δχ: [Float], Δμ: [Float], Δσ: [Float], Δ delta: [Float], μ mu: [Float], λ lambda: [Float]) {
		
	}
	static func gainχ(χ: LaObjet) -> (μ: LaObjet, σ: LaObjet) {
		return (χ, χ)
	}
	static func Δ(Δ: (μ: LaObjet, σ: LaObjet), μ: LaObjet, σ: LaObjet, Σ: (μ: LaObjet, λ: LaObjet)) -> (μ: LaObjet, σ: LaObjet) {
		return (
			μ: Δ.μ,
			σ: Δ.σ
		)
	}
	static func Δμ(Δ Δ: LaObjet, μ: LaObjet) -> LaObjet {
		return Δ
	}
	static func Δσ(Δ Δ: LaObjet, σ: LaObjet) -> LaObjet {
		return Δ
	}
	static func synthesize(χ χ: [Float], μ: [Float], λ: [Float], refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)]) {
		let mix: (χ: LaObjet, μ: LaObjet, λ: LaObjet) = refer.reduce((LaValuer(0), LaValuer(0), LaValuer(0))) {
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