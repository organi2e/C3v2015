//
//  Gauss.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Accelerate
internal class GaussianDistribution: StableDistribution {
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
	/*
	static func cdf(χ: LaObjet, μ: LaObjet, σ: LaObjet) -> LaObjet
	static func pdf(χ: LaObjet, μ: LaObjet, σ: LaObjet) -> LaObjet
	*/
	static func rng(μ mu: LaObjet, σ sigma: LaObjet) -> LaObjet {
		
		assert(mu.rows==sigma.rows)
		assert(mu.cols==sigma.cols)
		assert(sizeof(Float)==sizeof(UInt32))
		
		let rows: Int = min(mu.rows, sigma.rows)
		let cols: Int = min(mu.cols, sigma.cols)
		let count: Int = rows * cols
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*count))
		let uniform: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(count); defer { uniform.dealloc(count) }
		
		arc4random_buf(uniform, sizeof(Float)*count)
		
		vDSP_vfltu32(UnsafeMutablePointer<UInt32>(uniform), 1, uniform, 1, vDSP_Length(count))
		vDSP_vsadd(uniform, 1, [Float(1.0)], uniform, 1, vDSP_Length(count))
		vDSP_vsdiv(uniform, 1, [Float(UInt32.max)+1.0], uniform, 1, vDSP_Length(count))

		vDSP_vsmul(uniform, 1, [Float(2.0*M_PI)], uniform, 1, vDSP_Length(count/2))
		vvsincosf(buffer.advancedBy(0*count/2), buffer.advancedBy(1*count/2), uniform, [Int32(count/2)])
		
		vvlogf(uniform, uniform.advancedBy(count/2), [Int32(count/2)])
		vDSP_vsmul(uniform, 1, [Float(-2.0)], uniform, 1, vDSP_Length(count/2))
		vvsqrtf(uniform, uniform, [Int32(count/2)])
		vDSP_vmul(buffer.advancedBy(0*count/2), 1, uniform, 1, buffer.advancedBy(0*count/2), 1, vDSP_Length(count/2))
		vDSP_vmul(buffer.advancedBy(1*count/2), 1, uniform, 1, buffer.advancedBy(1*count/2), 1, vDSP_Length(count/2))
		
		return mu + sigma * matrix(buffer, rows: rows, cols: cols, deallocator: free)
	}
	
	static func est(χ: LaObjet) -> (μ: Float, σ: Float) {
		var μ: Float = 0.0
		var σ: Float = 0.0
		let array: [Float] = χ.array
		vDSP_meanv(array, 1, &μ, vDSP_Length(array.count))
		vDSP_vsadd(array, 1, [-μ], UnsafeMutablePointer(array), 1, vDSP_Length(array.count))
		vDSP_vsq(array, 1, UnsafeMutablePointer(array), 1, vDSP_Length(array.count))
		vDSP_meanv(array, 1, &σ, vDSP_Length(array.count))
		return (μ, sqrt(σ))
	}
}