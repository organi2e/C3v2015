//
//  Gauss.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Accelerate
import simd
internal class GaussianDistribution: SymmetricStableDistribution {
	static var N: Float { return 2 }
	private static let CDF: String = "gaussCDF"
	private static let PDF: String = "gaussPDF"
	private static let RNG: String = "gaussRNG"

	private let group: dispatch_group_t = dispatch_group_create()
	private let cache: Buffer
	private let cdf: Pipeline
	private let pdf: Pipeline
	private let rng: Pipeline
	
	init(context: Context, block: Int = 256) throws {
		cache = context.newBuffer(length: sizeof(uint)*4*block, options: .CPUCacheModeWriteCombined)
		arc4random_buf(cache.bytes, cache.length)
		cdf = try context.newPipeline(self.dynamicType.CDF)
		pdf = try context.newPipeline(self.dynamicType.PDF)
		rng = try context.newPipeline(self.dynamicType.RNG)
	}
	
	func cdf(compute: Compute, χ: Buffer, μ: Buffer, λ: Buffer) {
		
		let length: Int = min(χ.length, μ.length, λ.length)
		let count: Int = length / sizeof(Float)
		var _M_SQRT1_2: Float = Float(M_SQRT1_2)
		
		assert(length==χ.length)
		assert(length==μ.length)
		assert(length==λ.length)
		
		compute.setComputePipelineState(cdf)
		compute.setBuffer(χ, offset: 0, atIndex: 0)
		compute.setBuffer(μ, offset: 0, atIndex: 1)
		compute.setBuffer(λ, offset: 0, atIndex: 2)
		compute.setBytes(&_M_SQRT1_2, length: sizeof(Float), atIndex: 3)
		compute.dispatch(grid: ((count+3)/4, 1, 1), threads: (1, 1, 1))
		
	}
	func pdf(compute: Compute, χ: Buffer, μ: Buffer, λ: Buffer) {
		
		let length: Int = min(χ.length, μ.length, λ.length)
		let count: Int = length / sizeof(Float)
		var _M_SQRT1_2PI: Float = Float(0.5*M_2_SQRTPI*M_SQRT1_2)
		
		assert(length==χ.length)
		assert(length==μ.length)
		assert(length==λ.length)
		
		compute.setComputePipelineState(pdf)
		compute.setBuffer(χ, offset: 0, atIndex: 0)
		compute.setBuffer(μ, offset: 0, atIndex: 1)
		compute.setBuffer(λ, offset: 0, atIndex: 2)
		compute.setBytes(&_M_SQRT1_2PI, length: sizeof(Float), atIndex: 3)
		compute.dispatch(grid: ((count+3)/4, 1, 1), threads: (1, 1, 1))
		
	}
	func rng(compute: Compute, χ: Buffer, μ: Buffer, σ: Buffer) {
		
		let length: Int = min(χ.length, μ.length, σ.length)
		let count: Int = length / sizeof(Float)
		
		let block: Int = cache.length / sizeof(uint)
		
		assert(length==χ.length)
		assert(length==μ.length)
		assert(length==σ.length)

		arc4random_buf(cache.bytes, cache.length)
		
		compute.setComputePipelineState(rng)
		compute.setBuffer(χ, offset: 0, atIndex: 0)
		compute.setBuffer(μ, offset: 0, atIndex: 1)
		compute.setBuffer(σ, offset: 0, atIndex: 2)
		compute.setBuffer(cache, offset: 0, atIndex: 3)
		compute.setBytes([uint]([13, 17, 5, uint(count+3)/4]), length: sizeof(uint)*4, atIndex: 4)
		compute.dispatch(grid: (block/4, 1, 1), threads: (1, 1, 1))
		
	}
	func μrate(μ: LaObjet) -> LaObjet {
		return μ
	}
	func σrate(σ: LaObjet) -> LaObjet {
		return σ * σ
	}
	func xrate(x: LaObjet) -> LaObjet {
		return x
	}
	func yrate(y: LaObjet, dy: LaObjet) -> LaObjet {
		return y * dy
	}
	func λrate(λ: Buffer, σ: Buffer) {
		var length: Int32 = Int32(min(λ.length, σ.length)/sizeof(Float))
		vvrsqrtf(λ.bytes, σ.bytes, &length)
	}
	func gradμ(μ: LaObjet) -> LaObjet {
		return LaIdentité(μ.count)
	}
	func gradσ(σ: LaObjet) -> LaObjet {
		return σ
	}
	func gradλ(λ: LaObjet) -> LaObjet {
		return λ * λ * λ
	}
	static func test1(λ: LaObjet) -> LaObjet {
		return -λ * λ * λ
	}
	static func test2(b: LaObjet) -> LaObjet {
		return b * b
	}
	static func test3(y: LaObjet) -> LaObjet {
		return y
	}
	func gainχ(χ: LaObjet) -> (μ: LaObjet, σ: LaObjet) {
		return(χ, χ * χ)
	}
	
	func Δμ(Δ Δ: LaObjet, μ: LaObjet) -> LaObjet {
		return Δ
	}
	
	func Δσ(Δ Δ: LaObjet, σ: LaObjet) -> LaObjet {
		return Δ * σ
	}
	func est(χ: Buffer) -> (μ: Float, σ: Float) {
		var μ: Float = 0.0
		var σ: Float = 1.0
		vDSP_normalize(χ.bytes, 1, nil, 1, &μ, &σ, vDSP_Length(χ.length/sizeof(Float)))
		return (μ, σ)
	}
	/*
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
	static func rng(χ: UnsafeMutablePointer<Float>, ψ: UnsafePointer<UInt32>, μ: UnsafePointer<Float>, σ: UnsafePointer<Float>, count: Int) {
		
		let length: vDSP_Length = vDSP_Length(count)
		
		var half: Int32 = Int32(length/2)
		var gain: Float = Float(1/(Double(UInt32.max)+1))
		
		vDSP_vfltu32(ψ, 1, UnsafeMutablePointer<Float>(ψ), 1, length)
		vDSP_vsmsa(UnsafePointer<Float>(ψ), 1, &gain, &gain, UnsafeMutablePointer<Float>(ψ), 1, length)
		cblas_sscal(half, Float(2*M_PI), UnsafeMutablePointer<Float>(ψ), 1)
		
		vvsincosf(χ.advancedBy(0*count/2), χ.advancedBy(1*count/2), UnsafePointer<Float>(ψ), &half)
		vvlogf(UnsafeMutablePointer<Float>(ψ), UnsafePointer<Float>(ψ).advancedBy(count/2), &half)
		cblas_sscal(half, -2, UnsafeMutablePointer<Float>(ψ), 1)
		
		vvsqrtf(UnsafeMutablePointer<Float>(ψ), UnsafePointer<Float>(ψ), &half)
		
		vDSP_vmul(χ.advancedBy(0*count/2), 1, UnsafePointer<Float>(ψ), 1, χ.advancedBy(0*count/2), 1, length/2)
		vDSP_vmul(χ.advancedBy(1*count/2), 1, UnsafePointer<Float>(ψ), 1, χ.advancedBy(1*count/2), 1, length/2)
		
		vDSP_vma(χ, 1, σ, 1, μ, 1, χ, 1, length)
		
	}
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
		
		let length: vDSP_Length = vDSP_Length(count)
		
		var zero: Float = 0.0
		var half: Float = 0.5
		var nega: Float = -1.0
		
		vDSP_vneg(φ, 1, κ, 1, length)
		vDSP_vthrsc(κ, 1, &zero, &half, κ, 1, length)
		vDSP_vsmsa(κ, 1, &nega, &half, κ, 1, length)
		
	}
	static func derivate(Δ: (χ: UnsafeMutablePointer<Float>, μ: UnsafeMutablePointer<Float>, σ: UnsafeMutablePointer<Float>), δ: UnsafePointer<Float>, μ: UnsafePointer<Float>, λ: UnsafePointer<Float>, count: Int) {
		
		let length: vDSP_Length = vDSP_Length(count)
		
		var len: Int32 = Int32(count)
		
		var zero: Float = 0
		var posi: Float = 0.5
		var nega: Float = -0.5
		
		vDSP_vneg(δ, 1, Δ.σ, 1, length)
		vDSP_vlim(δ, 1, &zero, &posi, Δ.μ, 1, length)
		vDSP_vlim(Δ.σ, 1, &zero, &nega, Δ.σ, 1, length)
		vDSP_vadd(Δ.μ, 1, Δ.σ, 1, Δ.χ, 1, length)//Δ.χ = sign(δ)
		
		vDSP_vmul(μ, 1, λ, 1, Δ.σ, 1, length)//Δ.σ = μ * λ
		vDSP_vsq(Δ.σ, 1, Δ.μ, 1, length)//Δ.μ = ( μ * λ ) ^ 2
		cblas_sscal(len, nega, Δ.μ, 1)//Δ.μ = -0.5 * ( μ * λ ) ^ 2
		
		vvexpf(Δ.μ, Δ.μ, &len)
		cblas_sscal(len, Float(0.5 * M_2_SQRTPI * M_SQRT1_2), Δ.μ, 1)
		vDSP_vmul(Δ.χ, 1, Δ.μ, 1, Δ.χ, 1, length)
		
		vDSP_vmul(Δ.χ, 1, λ, 1, Δ.μ, 1, length)
		vDSP_vmul(Δ.μ, 1, Δ.σ, 1, Δ.σ, 1, length)
		vDSP_vmul(Δ.σ, 1, λ, 1, Δ.σ, 1, length)
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
	static func synthesize(χ χ: UnsafeMutablePointer<Float>, μ: UnsafeMutablePointer<Float>, λ: UnsafeMutablePointer<Float>, refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)], count: Int) {
		func σ(σ: LaObjet) -> LaObjet { return σ * σ }
		var len: Int32 = Int32(count)
		let mix: (χ: LaObjet, μ: LaObjet, λ: LaObjet) = refer.reduce((LaValuer(0), LaValuer(0), LaValuer(0))) {
			( $0.0.0 + $0.1.χ, $0.0.1 + $0.1.1, $0.0.2 + σ($0.1.σ) )
		}
		mix.χ.getBytes(χ)
		mix.μ.getBytes(μ)
		mix.λ.getBytes(λ)
		vvrsqrtf(UnsafeMutablePointer<Float>(λ), λ, &len)
	}
	*/
}