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
internal class PulseDistribution: SymmetricStableDistribution {
	func cdf(compute: Compute, χ: Buffer, μ: Buffer, λ: Buffer) {
		for k in 0..<min(χ.length, μ.length)/sizeof(Float) {
			χ.bytes[k] = 0 < μ.bytes[k] ? 1 : 0
		}
	}
	func pdf(compute: Compute, χ: Buffer, μ: Buffer, λ: Buffer) {
		for k in 0..<min(χ.length, μ.length)/sizeof(Float) {
			χ.bytes[k] = 0 == μ.bytes[k] ? 1 : 0
		}
	}
	func gradient(compute: Compute, gradμ: Buffer, gradλ: Buffer, μ: Buffer, λ: Buffer) {
	
	}
	func rng(compute: Compute, χ: Buffer, μ: Buffer, σ: Buffer) {
		cblas_scopy(Int32(min(χ.length, μ.length)/sizeof(Float)), μ.bytes, 1, χ.bytes, 1)
	}
	func μrate(μ: LaObjet) -> LaObjet {
		return μ
	}
	func σrate(σ: LaObjet) -> LaObjet {
		return LaValuer(0)
	}
	func λrate(λ: Buffer, σ: Buffer) {
		vvrecf(λ.bytes, σ.bytes, [Int32(min(λ.length, σ.length)/sizeof(Float))])
	}
	func μxrate(x: LaObjet) -> LaObjet {
		return LaValuer(1)
	}
	func μyrate(y: LaObjet, dy: LaObjet) -> LaObjet {
		return LaValuer(1)
	}
	func σxrate(x: LaObjet) -> LaObjet {
		return LaValuer(0)
	}
	func σyrate(y: LaObjet, dy: LaObjet) -> LaObjet {
		return LaValuer(0)
	}
}
internal protocol SymmetricStableDistribution: StableDistribution {
	func μxrate(x: LaObjet) -> LaObjet
	func μyrate(y: LaObjet, dy: LaObjet) -> LaObjet
	func σxrate(x: LaObjet) -> LaObjet
	func σyrate(y: LaObjet, dy: LaObjet) -> LaObjet
}
internal protocol StableDistribution: Distribution {
	func μrate(μ: LaObjet) -> LaObjet
	func σrate(σ: LaObjet) -> LaObjet
	func λrate(λ: Buffer, σ: Buffer)
	func gradient(compute: Compute, gradμ: Buffer, gradλ: Buffer, μ: Buffer, λ: Buffer)
}
internal protocol Distribution {
	func cdf(compute: Compute, χ: Buffer, μ: Buffer, λ: Buffer)
	func pdf(compute: Compute, χ: Buffer, μ: Buffer, λ: Buffer)
	func rng(compute: Compute, χ: Buffer, μ: Buffer, σ: Buffer)
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
	static var N: Float { return Float.NaN }
	func cdf(compute: Compute, χ: Buffer, μ: Buffer, λ: Buffer) {}
	func pdf(compute: Compute, χ: Buffer, μ: Buffer, λ: Buffer) {}
	func rng(compute: Compute, χ: Buffer, μ: Buffer, σ: Buffer) {}
	
	func μ(μ: LaObjet) -> LaObjet {
		return μ
	}
	func σ(σ: LaObjet) -> LaObjet {
		return σ
	}
	func Δμ(Δ Δ: LaObjet, μ: LaObjet) -> LaObjet {
		return LaValuer(1)
	}
	func Δσ(Δ Δ: LaObjet, σ: LaObjet) -> LaObjet {
		return LaValuer(1)
	}
	func gainχ(χ: LaObjet) -> (μ: LaObjet, σ: LaObjet) {
		return(χ, LaValuer(1))
	}
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
