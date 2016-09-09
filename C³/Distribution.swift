//
//  Distribution.swift
//  C³
//
//  Created by Kota Nakano on 8/29/16.
//
//
import Accelerate
public enum DistributionType: String {
	case Gauss = "Gauss"
	case Cauchy = "Cauchy"
	case False = "False"
}
internal protocol RandomNumberGeneratable {
	var χ: LaObjet { get }
	var μ: LaObjet { get }
	var σ: LaObjet { get }
}
internal protocol Distribution {
	
	func cdf(compute: Compute, χ: Buffer, μ: Buffer, λ: Buffer)
	func pdf(compute: Compute, χ: Buffer, μ: Buffer, λ: Buffer)
	func rng(compute: Compute, χ: Buffer, μ: Buffer, σ: Buffer)
	func gainχ(χ: LaObjet) -> (μ: LaObjet, σ: LaObjet)
	func Δμ(Δ Δ: LaObjet, μ: LaObjet) -> LaObjet
	func Δσ(Δ Δ: LaObjet, σ: LaObjet) -> LaObjet
	func synthesize(χ χ: Buffer, μ: Buffer, λ: Buffer, refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)])
	/*
	static func cdf(χ: Float, μ: Float, σ: Float) -> Float
	static func pdf(χ: Float, μ: Float, σ: Float) -> Float

	static func rng(context: Context, χ: Buffer, μ: Buffer, σ: Buffer, count: Int)
	static func rng(χ: UnsafeMutablePointer<Float>, ψ: UnsafePointer<UInt32>, μ: UnsafePointer<Float>, σ: UnsafePointer<Float>, count: Int)
	//static func rng(χ: [Float], ψ: [UInt32], μ: LaObjet, σ: LaObjet)
	
	static func gainχ(χ: LaObjet) -> (μ: LaObjet, σ: LaObjet)
	
	static func Δ(Δ: (μ: LaObjet, σ: LaObjet), μ: LaObjet, σ: LaObjet, Σ: (μ: LaObjet, λ: LaObjet)) -> (μ: LaObjet, σ: LaObjet)
	static func Δμ(Δ Δ: LaObjet, μ: LaObjet) -> LaObjet
	static func Δσ(Δ Δ: LaObjet, σ: LaObjet) -> LaObjet
	static func activate(κ: UnsafeMutablePointer<Float>, φ: UnsafePointer<Float>, count: Int)
	static func derivate(Δ: (χ: UnsafeMutablePointer<Float>, μ: UnsafeMutablePointer<Float>, σ: UnsafeMutablePointer<Float>), δ: UnsafePointer<Float>, μ: UnsafePointer<Float>, λ: UnsafePointer<Float>, count: Int)
	//static func derivate(Δχ Δχ: [Float], Δμ: [Float], Δσ: [Float], Δ: [Float], μ: [Float], λ: [Float])
	
	static func synthesize(χ χ: UnsafeMutablePointer<Float>, μ: UnsafeMutablePointer<Float>, λ: UnsafeMutablePointer<Float>, refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)], count: Int)
	//static func synthesize(χ χ: [Float], μ: [Float], λ: [Float], refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)])
	*/
}
internal class FalseDistribution: Distribution {
	
	func cdf(compute: Compute, χ: Buffer, μ: Buffer, λ: Buffer) {}
	func pdf(compute: Compute, χ: Buffer, μ: Buffer, λ: Buffer) {}
	func rng(compute: Compute, χ: Buffer, μ: Buffer, σ: Buffer) {}
	func Δμ(Δ Δ: LaObjet, μ: LaObjet) -> LaObjet {
		return LaValuer(1)
	}
	func Δσ(Δ Δ: LaObjet, σ: LaObjet) -> LaObjet {
		return LaValuer(1)
	}
	func gainχ(χ: LaObjet) -> (μ: LaObjet, σ: LaObjet) {
		return(χ, LaValuer(1))
	}
	func synthesize(χ χ: Buffer, μ: Buffer, λ: Buffer, refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)]) {}
	/*
	static func cdf(χ: Float, μ: Float, σ: Float) -> Float { return μ >= χ ? 0 : 1 }
	static func pdf(χ: Float, μ: Float, σ: Float) -> Float { return μ != χ ? 0 : 1 }
	static func generate(context: Context, compute: Compute, χ: Buffer, μ: Buffer, σ: Buffer) {}
	static func rng(χ: UnsafeMutablePointer<Float>, ψ: UnsafePointer<UInt32>, μ: UnsafePointer<Float>, σ: UnsafePointer<Float>, count: Int) {
		
	}
	static func rng(context: Context, χ: Buffer, μ: Buffer, σ: Buffer, count: Int) {
	
	}
	static func rng(χ: [Float], ψ: [UInt32], μ: LaObjet, σ: LaObjet) {
		μ.getBytes(χ)
	}
	static func gainχ(χ: LaObjet) -> (μ: LaObjet, σ: LaObjet) {
		return (
			LaValuer(1),
			LaValuer(1)
		)
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
	static func activate(κ: UnsafeMutablePointer<Float>, φ: UnsafePointer<Float>, count: Int) {
		cblas_scopy(Int32(count), φ, 1, κ, 1)
	}
	static func derivate(Δ: (χ: UnsafeMutablePointer<Float>, μ: UnsafeMutablePointer<Float>, σ: UnsafeMutablePointer<Float>), δ: UnsafePointer<Float>, μ: UnsafePointer<Float>, λ: UnsafePointer<Float>, count: Int) {
		cblas_scopy(Int32(count), δ, 1, Δ.χ, 1)
		cblas_scopy(Int32(count), δ, 1, Δ.μ, 1)
	}
	static func derivate(Δχ Δχ: [Float], Δμ: [Float], Δσ: [Float], Δ: [Float], μ: [Float], λ: [Float]) {
		cblas_scopy(Int32(min(Δ.count, Δχ.count)), Δ, 1, UnsafeMutablePointer<Float>(Δχ), 1)
		cblas_scopy(Int32(min(Δ.count, Δμ.count)), Δ, 1, UnsafeMutablePointer<Float>(Δμ), 1)
		vDSP_vclr(UnsafeMutablePointer<Float>(Δσ), 1, vDSP_Length(Δσ.count))
	}
	
	static func synthesize(χ χ: UnsafeMutablePointer<Float>, μ: UnsafeMutablePointer<Float>, λ: UnsafeMutablePointer<Float>, refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)], count: Int) {
		
	}
	static func synthesize(χ χ: [Float], μ: [Float], λ: [Float], refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)]) {
		let mix: (χ: LaObjet, μ: LaObjet, LaObjet) = refer.reduce((LaValuer(0), LaValuer(0), LaValuer(0))) {
			($0.0.0 + $0.1.χ, $0.0.1 + $0.1.μ, LaValuer(0))
		}
		mix.χ.getBytes(χ)
		mix.μ.getBytes(μ)
		vDSP_vclr(UnsafeMutablePointer<Float>(λ), 1, vDSP_Length(λ.count))
	}
	*/
}
