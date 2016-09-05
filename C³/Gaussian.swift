//
//  Gauss.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Accelerate
import simd
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
		var σ: Float = 1.0
		vDSP_normalize(χ, 1, nil, 1, &μ, &σ, vDSP_Length(χ.count))
		return (μ, σ)
	}
	static func gainχ(χ: LaObjet) -> (μ: LaObjet, σ: LaObjet) {
		return ( χ, χ * χ )
	}
	static func Δ(Δ: (μ: LaObjet, σ: LaObjet), μ: LaObjet, σ: LaObjet, Σ: (μ: LaObjet, λ: LaObjet)) -> (μ: LaObjet, σ: LaObjet) {
		return (
			μ: Δ.μ,
			σ: Δ.σ * σ * Σ.λ
		)
	}
	static func Δμ(Δ Δ: LaObjet, μ: LaObjet) -> LaObjet {
		return Δ
	}
	static func Δσ(Δ Δ: LaObjet, σ: LaObjet) -> LaObjet {
		return σ * Δ
	}
	static func activate(κ: UnsafeMutablePointer<Float>, φ: UnsafePointer<Float>, count: Int) {
		/*
		let κref: UnsafeMutablePointer<float4> = UnsafeMutablePointer<float4>(κ)
		let φref: UnsafePointer<float4> = UnsafePointer<float4>(φ)
		(0..<count/4).forEach {
			κref[$0] = vector_step(float4(0.0), φref[$0])
		}*/
		let length: vDSP_Length = vDSP_Length(count)
		var zero: Float = 0.0
		var half: Float = 0.5
		var nega: Float = -1.0
		vDSP_vneg(φ, 1, κ, 1, length)
		vDSP_vthrsc(κ, 1, &zero, &half, κ, 1, length)
		vDSP_vsmsa(κ, 1, &nega, &half, κ, 1, length)
	}
	static func derivate(Δ: (χ: UnsafeMutablePointer<Float>, μ: UnsafeMutablePointer<Float>, σ: UnsafeMutablePointer<Float>), δ: UnsafePointer<Float>, μ: UnsafePointer<Float>, λ: UnsafePointer<Float>, count: Int) {
		/*
		let κref: UnsafeMutablePointer<float4> = UnsafeMutablePointer<float4>(Δ.χ)
		let φref: UnsafePointer<float4> = UnsafePointer<float4>(δ)
		(0..<count/4).forEach {
			κref[$0] = vector_sign(φref[$0])
		}
		*/
		let length: vDSP_Length = vDSP_Length(count)
		var len: Int32 = Int32(count)
		var zero: Float = 0
		var posi: Float = 0.5
		var nega: Float = -0.5
		var gain: Float = Float(0.5 * M_2_SQRTPI * M_SQRT1_2)
		
		vDSP_vneg(δ, 1, Δ.σ, 1, length)
		vDSP_vlim(δ, 1, &zero, &posi, Δ.μ, 1, length)
		vDSP_vlim(Δ.σ, 1, &zero, &nega, Δ.σ, 1, length)

		vDSP_vmul(μ, 1, λ, 1, Δ.χ, 1, length)
		vDSP_vsq(Δ.χ, 1, Δ.χ, 1, length)
		vDSP_vsmul(Δ.χ, 1, &nega, Δ.χ, 1, length)
		
		vvexpf(Δ.χ, Δ.χ, &len)
		
		vDSP_vsmul(Δ.χ, 1, &gain, Δ.χ, 1, length)
		vDSP_vam(Δ.μ, 1, Δ.σ, 1, Δ.χ, 1, Δ.χ, 1, length)
		
		vDSP_vmul(Δ.χ, 1, λ, 1, Δ.μ, 1, length)
		vDSP_vmul(Δ.μ, 1, λ, 1, Δ.σ, 1, length)
		vDSP_vmul(Δ.σ, 1, μ, 1, Δ.σ, 1, length)
		vDSP_vneg(Δ.σ, 1, Δ.σ, 1, length)		
		
	}
	static func derivate(Δχ Δχ: [Float], Δμ: [Float], Δσ: [Float], Δ delta: [Float], μ mu: [Float], λ lambda: [Float]) {
		
		let χ: LaObjet = LaMatrice(Δχ, rows: Δχ.count, cols: 1, deallocator: nil)
		let Δ: LaObjet = LaMatrice(delta, rows: delta.count, cols: 1, deallocator: nil)
		let μ: LaObjet = LaMatrice(mu, rows: mu.count, cols: 1, deallocator: nil)
		let λ: LaObjet = LaMatrice(lambda, rows: lambda.count, cols: 1, deallocator: nil)
		
		( -0.5 * ( λ * μ ) * ( λ * μ ) ).getBytes(Δχ)
		
		vvexpf(UnsafeMutablePointer<Float>(Δχ), Δχ, [Int32(Δχ.count)])
		(Float(0.5*M_2_SQRTPI*M_SQRT1_2)*Δ*χ).getBytes(Δχ)
		
		(  1.0 * χ * λ ).getBytes(Δμ)
		( -1.0 * χ * μ * λ * λ ).getBytes(Δσ)
		//vDSP_vneg(Δσ, 1, UnsafeMutablePointer<Float>(Δσ), 1, vDSP_Length(Δσ.count))
	}
	static func synthesize(χ χ: [Float], μ: [Float], λ: [Float], refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)]) {
		func σ(σ: LaObjet) -> LaObjet { return σ * σ }
		let mix: (χ: LaObjet, μ: LaObjet, λ: LaObjet) = refer.reduce((LaValuer(0), LaValuer(0), LaValuer(0))) {
			( $0.0.0 + $0.1.χ, $0.0.1 + $0.1.1, $0.0.2 + σ($0.1.σ) )
		}
		mix.χ.getBytes(χ)
		mix.μ.getBytes(μ)
		mix.λ.getBytes(λ)
		vvrsqrtf(UnsafeMutablePointer<Float>(λ), λ, [Int32(λ.count)])
	}
}