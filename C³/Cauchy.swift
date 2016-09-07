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
			M_1_PI / ( Double(σ) * ( 1.0 + level * level ) )
		)
	}
	//	static func cdf(χ: LaObjet, μ: LaObjet, σ: LaObjet) -> LaObjet
	//	static func pdf(χ: LaObjet, μ: LaObjet, σ: LaObjet) -> LaObjet
	static func rng(χ: UnsafeMutablePointer<Float>, ψ: UnsafePointer<UInt32>, μ: UnsafePointer<Float>, σ: UnsafePointer<Float>, count: Int) {
		let length: vDSP_Length = vDSP_Length(count)
		var len: Int32 = Int32(length)
		var gain: Float = Float(1/(Double(UInt32.max)+1))
		var bias: Float = 0.5 * gain
		vDSP_vfltu32(ψ, 1, χ, 1, length)
		vDSP_vsmsa(χ, 1, &gain, &bias, χ, 1, length)
		vvtanpif(χ, χ, &len)
		vDSP_vma(χ, 1, σ, 1, μ, 1, χ, 1, length)
	}
	static func activate(κ: UnsafeMutablePointer<Float>, φ: UnsafePointer<Float>, count: Int) {
		
		let length: vDSP_Length = vDSP_Length(count)
		
		var zero: Float = 0.0
		var half: Float = 0.5
		
		vDSP_vneg(φ, 1, κ, 1, length)
		vDSP_vthrsc(κ, 1, &zero, &half, κ, 1, length)
		vDSP_vneg(κ, 1, κ, 1, length)
		vDSP_vsadd(κ, 1, &half, κ, 1, length)
		
	}
	static func derivate(Δ: (χ: UnsafeMutablePointer<Float>, μ: UnsafeMutablePointer<Float>, σ: UnsafeMutablePointer<Float>), δ: UnsafePointer<Float>, μ: UnsafePointer<Float>, λ: UnsafePointer<Float>, count: Int) {
		
		let length: vDSP_Length = vDSP_Length(count)
		
		var len: Int32 = Int32(count)

		var one: Float = 1.0
		var zero: Float = 0
		var posi: Float = 0.5
		var nega: Float = -0.5
		
		vDSP_vneg(δ, 1, Δ.σ, 1, length)
		vDSP_vlim(δ, 1, &zero, &posi, Δ.μ, 1, length)
		vDSP_vlim(Δ.σ, 1, &zero, &nega, Δ.σ, 1, length)
		vDSP_vadd(Δ.μ, 1, Δ.σ, 1, Δ.χ, 1, length)
		
		vDSP_vmul(μ, 1, λ, 1, Δ.σ, 1, length)
		vDSP_vsq(Δ.σ, 1, Δ.μ, 1, length)
		vDSP_vsadd(Δ.μ, 1, &one, Δ.μ, 1, length)
		
		cblas_sscal(len, Float(M_1_PI), Δ.χ, 1)
		vvdivf(Δ.χ, Δ.χ, Δ.μ, &len)
		
		vDSP_vmul(Δ.χ, 1, λ, 1, Δ.μ, 1, length)
		vDSP_vmul(Δ.μ, 1, Δ.σ, 1, Δ.σ, 1, length)
		vDSP_vneg(Δ.σ, 1, Δ.σ, 1, length)
		
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
	
	static func synthesize(χ χ: UnsafeMutablePointer<Float>, μ: UnsafeMutablePointer<Float>, λ: UnsafeMutablePointer<Float>, refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)], count: Int) {
		var len: Int32 = Int32(count)
		let mix: (χ: LaObjet, μ: LaObjet, λ: LaObjet) = refer.reduce((LaValuer(0), LaValuer(0), LaValuer(0))) {
			( $0.0.0 + $0.1.χ, $0.0.1 + $0.1.1, $0.0.2 + $0.1.σ )
		}
		mix.χ.getBytes(χ)
		mix.μ.getBytes(μ)
		mix.λ.getBytes(λ)
		vvrecf(UnsafeMutablePointer<Float>(λ), λ, &len)
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