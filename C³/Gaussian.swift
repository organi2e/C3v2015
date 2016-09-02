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
	static func rng(χ: [Float], ψ: [UInt32], μ: LaObjet, σ: LaObjet) {

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
		
		
		(LaMatrice(χ, rows: min(μ.rows, σ.rows), cols: min(μ.cols, σ.cols), deallocator: nil)*σ+μ).eval(χ)
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
	static func gradμ(μ μ: LaObjet, χ: LaObjet) -> LaObjet {
		return χ
	}
	static func gradσ(σ σ: LaObjet, χ: LaObjet) -> LaObjet {
		return 2 * σ * χ * χ
	}
	static func derivate(Δχ Δχ: [Float], Δμ: [Float], Δσ: [Float], Δ: LaObjet, μ: LaObjet, λ: LaObjet) {
		let χ: LaObjet = LaMatrice(Δχ, rows: Δχ.count, cols: 1)
		
		let λμ: LaObjet = λ * μ
		(-0.5 * λμ * λμ).getBytes(Δχ)
		vvexpf(UnsafeMutablePointer<Float>(Δχ), Δχ, [Int32(Δχ.count)])
		
		(Float(0.5*M_2_SQRTPI*M_SQRT1_2)*Δ*χ).getBytes(Δχ)
		
		let λχ: LaObjet = λ * χ
		(λχ).getBytes(Δμ)
		(-0.5*λχ*μ*λ*λ).getBytes(Δσ)
		//vDSP_vneg(Δσ, 1, UnsafeMutablePointer<Float>(Δσ), 1, vDSP_Length(Δσ.count))
	}
	static func synthesize(χ χ: [Float], μ: [Float], λ: [Float], refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)]) {
		func σ(σ: LaObjet) -> LaObjet { return σ * σ }
		let mix: (χ: LaObjet, μ: LaObjet, λ: LaObjet) = refer.reduce((LaSplat(0), LaSplat(0), LaSplat(0))) {
			( $0.0.0 + $0.1.χ, $0.0.1 + $0.1.1, $0.0.2 + σ($0.1.σ) )
		}
		mix.χ.getBytes(χ)
		mix.μ.getBytes(μ)
		mix.λ.getBytes(λ)
		vvrsqrtf(UnsafeMutablePointer<Float>(λ), λ, [Int32(λ.count)])
	}
}