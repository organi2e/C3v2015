//
//  Gauss.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Accelerate
internal class GaussianDistribution: Distribution {
	static func cdf(χ: Float, μ: Float, σ: Float) -> Float {
		let level: Double = ( Double(χ) - Double(μ) ) / Double(σ)
		return Float(
			-0.5*erfc(-level*M_SQRT1_2)
		)
	}
	static func pdf(χ: Float, μ: Float, σ: Float) -> Float {
		let level: Double = ( Double(χ) - Double(μ) ) / Double(σ)
		return Float(
			M_SQRT1_2*M_2_SQRTPI*exp(-0.5*level*level)/Double(σ)
		)
	}
	static func pdf(buffer: [Float], μ: Float, σ: Float) {
	
	}
	/*
	static func cdf(χ: LaObjet, μ: LaObjet, σ: LaObjet) -> LaObjet
	static func pdf(χ: LaObjet, μ: LaObjet, σ: LaObjet) -> LaObjet
	*/
	static func rng(χ: [Float], μ: [Float], σ: [Float], ψ: [UInt32]) {

		let count: Int = χ.count

		assert(μ.count==count)
		assert(σ.count==count)
		assert(ψ.count==count)
		
		vDSP_vfltu32(ψ, 1, UnsafeMutablePointer<Float>(ψ), 1, vDSP_Length(count))
		vDSP_vsadd(UnsafeMutablePointer<Float>(ψ), 1, [Float(1.0)], UnsafeMutablePointer<Float>(ψ), 1, vDSP_Length(count))
		vDSP_vsdiv(UnsafeMutablePointer<Float>(ψ), 1, [Float(UInt32.max)+1.0], UnsafeMutablePointer<Float>(ψ), 1, vDSP_Length(count))
		
		vDSP_vsmul(UnsafeMutablePointer<Float>(ψ), 1, [Float(2.0*M_PI)], UnsafeMutablePointer<Float>(ψ), 1, vDSP_Length(count/2))
		vvsincosf(UnsafeMutablePointer<Float>(χ).advancedBy(0*count/2), UnsafeMutablePointer<Float>(χ).advancedBy(1*count/2), UnsafeMutablePointer<Float>(ψ), [Int32(count/2)])
		
		vvlogf(UnsafeMutablePointer<Float>(ψ), UnsafeMutablePointer<Float>(ψ).advancedBy(count/2), [Int32(count/2)])
		vDSP_vsmul(UnsafeMutablePointer<Float>(ψ), 1, [Float(-2.0)], UnsafeMutablePointer<Float>(ψ), 1, vDSP_Length(count/2))
		vvsqrtf(UnsafeMutablePointer<Float>(ψ), UnsafeMutablePointer<Float>(ψ), [Int32(count/2)])
		vDSP_vmul(UnsafeMutablePointer<Float>(χ).advancedBy(0*count/2), 1, UnsafeMutablePointer<Float>(ψ), 1, UnsafeMutablePointer<Float>(χ).advancedBy(0*count/2), 1, vDSP_Length(count/2))
		vDSP_vmul(UnsafeMutablePointer<Float>(χ).advancedBy(1*count/2), 1, UnsafeMutablePointer<Float>(ψ), 1, UnsafeMutablePointer<Float>(χ).advancedBy(1*count/2), 1, vDSP_Length(count/2))
		
		vDSP_vma(χ, 1, σ, 1, μ, 1, UnsafeMutablePointer<Float>(χ), 1, vDSP_Length(count))
		
	}
	static func est(χ: [Float]) -> (μ: Float, σ: Float) {
		var μ: Float = 0.0
		var σ: Float = 0.0
		let array: [Float] = χ
		vDSP_meanv(array, 1, &μ, vDSP_Length(array.count))
		vDSP_vsadd(array, 1, [-μ], UnsafeMutablePointer(array), 1, vDSP_Length(array.count))
		vDSP_vsq(array, 1, UnsafeMutablePointer(array), 1, vDSP_Length(array.count))
		vDSP_meanv(array, 1, &σ, vDSP_Length(array.count))
		return (μ, sqrt(σ))
	}
	static func χgain(input: LaObjet) -> LaObjet {
		return input
	}
	static func μgain(input: LaObjet) -> LaObjet {
		return input
	}
	static func σgain(input: LaObjet) -> LaObjet {
		return input * input
	}
	static func derivate(Δ: (χ: [Float], μ: [Float], σ: [Float]), μ: LaObjet, λ: LaObjet, δ: LaObjet) {
		let Δχ: LaObjet = LaMatrice(Δ.χ, rows: Δ.χ.count, cols: 1, deallocator: nil)
		(-0.5 * μ * λ * μ * λ).getBytes(Δ.χ)
		vvexpf(UnsafeMutablePointer<Float>(Δ.χ), Δ.χ, [Int32(Δ.χ.count)])
		(0.5*Float(M_2_SQRTPI)*Float(M_SQRT1_2)*Δχ*δ).getBytes(Δ.χ)
		(Δχ*λ).getBytes(Δ.μ)
		(-1*Δχ*μ*λ*λ).getBytes(Δ.μ)
	}
	static func synthesize(χ χ: [Float], μ: [Float], λ: [Float], refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)]) {
		let mix: (LaObjet, LaObjet, LaObjet) = refer.reduce((LaSplat(0), LaSplat(0), LaSplat(0))) {(x, y)->(LaObjet, LaObjet, LaObjet)in
			( x.0 + y.χ, x.1 + μgain(y.μ), x.2 + σgain(y.σ) )
		}
		mix.0.getBytes(χ)
		mix.1.getBytes(μ)
		mix.2.getBytes(λ)
		vvrsqrtf(UnsafeMutablePointer<Float>(λ), λ, [Int32(λ.count)])
	}
}