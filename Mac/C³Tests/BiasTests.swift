//
//  BlobTests.swift
//  Mac
//
//  Created by Kota Nakano on 7/23/16.
//
//
/*
import Accelerate
import XCTest
@testable import C3

func sigmaF(x: Float) -> Float {
	return log(exp(x)+1)
}
func sigmaI(y: Float) -> Float {
	return log(exp(y)-1)
}
func sigmaG(y: Float) -> Float {
	return 1 - exp(-y)
}
class BiasTests: XCTestCase {
	let context: Context = try!Context()
	
	let rows: Int = 8
	let cols: Int = 4
	
	func testGaussianCollect() {
		
		let χ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		let μ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		let λ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		
		let distribution = GaussianDistribution.self
		let bias: Bias! = context.new()
		
		bias.resize(rows: rows, cols: cols)
		bias.adjust(μ: 3, σ: 4)
		bias.shuffle(distribution)
		
		distribution.synthesize(χ: χ, μ: μ, λ: λ, refer: [bias.collect()])
		
		XCTAssert(χ.elementsEqual(bias.χ.array))
		XCTAssert(μ.elementsEqual(bias.μ.array))
		XCTAssert(λ.elementsEqual(bias.σ.array.map { 1 / $0 }))
		print(λ)
		print(bias.σ.array.map { 1 / $0 } )
	}
	func testCauchyCollect() {
		
		let χ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		let μ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		let λ: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		
		let distribution = CauchyDistribution.self
		let bias: Bias! = context.new()
		
		bias.resize(rows: rows, cols: cols)
		bias.adjust(μ: 2, σ: 4)
		bias.shuffle(distribution)
		
		distribution.synthesize(χ: χ, μ: μ, λ: λ, refer: [bias.collect()])
		
		XCTAssert(χ.elementsEqual(bias.χ.array))
		XCTAssert(μ.elementsEqual(bias.μ.array))
		XCTAssert(λ.elementsEqual(bias.σ.array.map { 1 / $0 } ))
		
	}
	func testGaussianCorrect() {
		
		
	}
	func testCauchyCorrect(){
		
		let count: Int = rows * cols
		
		let χ: [Float] = [Float](count: count, repeatedValue: 0)
		let μ: [Float] = [Float](count: count, repeatedValue: 0)
		let λ: [Float] = [Float](count: count, repeatedValue: 0)
		
		let distribution = CauchyDistribution.self
		let bias: Bias! = context.new()
		
		bias.resize(rows: rows, cols: cols)
		bias.adjust(μ: 2, σ: 4)
		bias.shuffle(distribution)
		
		distribution.synthesize(χ: χ, μ: μ, λ: λ, refer: [bias.collect()])
		
		XCTAssert(χ.elementsEqual(bias.χ.array))
		XCTAssert(μ.elementsEqual(bias.μ.array))
		XCTAssert(λ.elementsEqual(bias.σ.array.map { 1 / $0 }))
		print(λ)
		print(bias.σ.array.map { 1 / $0 } )
	}
}
/*
class BiasTests: XCTestCase {
	
	let context: Context = try!Context()
	let NOHINT: la_hint_t = la_hint_t(LA_NO_HINT)
	let ATTR: la_attribute_t = la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)
	let L2: la_norm_t = la_norm_t(LA_L2_NORM)
	
	func testCollect() {
		let width: Int = 256
		
		let bias_χ: MTLBuffer = context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
		let bias_μ: MTLBuffer = context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
		let bias_σ: MTLBuffer = context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
		let bias_logμ: MTLBuffer = context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
		let bias_logσ: MTLBuffer = context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
		
		let level_χ: MTLBuffer = context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
		let level_μ: MTLBuffer = context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
		let level_σ: MTLBuffer = context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
		
		context.newBlitCommand {(let encoder: MTLBlitCommandEncoder)in
			[level_χ, level_μ, level_σ].forEach {
				encoder.fillBuffer($0, range: NSRange(location: 0, length: $0.length), value: 0)
			}
		}
		
		let μ: Float = 0.5
		let σ: Float = 0.5
		
		Bias.adjust(context: context, logμ: bias_logμ, logσ: bias_logσ, parameter: (μ, σ))
		Bias.refresh(context: context, μ: bias_μ, σ: bias_σ, logμ: bias_logμ, logσ: bias_logσ)
		Bias.shuffle(context: context, χ: bias_χ, μ: bias_μ, σ: bias_σ)
		Bias.collect(context: context, level: (level_χ, level_μ, level_σ), bias: (bias_χ, bias_μ, level_σ), width: width)
		
		let srcχ: la_object_t = context.newLaObjectFromBuffer(bias_χ, rows: width, cols: 1)
		let dstχ: la_object_t = context.newLaObjectFromBuffer(level_χ, rows: width, cols: 1)
		
		let srcμ: la_object_t = context.newLaObjectFromBuffer(bias_μ, rows: width, cols: 1)
		let dstμ: la_object_t = context.newLaObjectFromBuffer(level_μ, rows: width, cols: 1)
		
		let srcσ: la_object_t = context.newLaObjectFromBuffer(level_σ, rows: width, cols: 1)
		let dstσ: la_object_t = context.newLaObjectFromBuffer(level_σ, rows: width, cols: 1)
		
		context.join()
		
		let errχ: Float = la_norm_as_float(la_difference(srcχ, dstχ), L2)
		let errμ: Float = la_norm_as_float(la_difference(srcμ, dstμ), L2)
		let errσ: Float = la_norm_as_float(la_difference(srcσ, dstσ), L2)

		XCTAssert(!isinf(errχ))
		XCTAssert(!isnan(errχ))
		
		if 1e-7 < errχ {
			XCTFail("\(errχ)")
		}
		
		XCTAssert(!isinf(errμ))
		XCTAssert(!isnan(errμ))
		
		if 1e-7 < errμ {
			XCTFail("\(errμ)")
		}
		
		XCTAssert(!isinf(errσ))
		XCTAssert(!isnan(errσ))
		
		if 1e-7 < errσ {
			XCTFail("\(errσ)")
		}
		
	}
	func testGradientEye() {
		let width: Int = 4
		
		var mu: [Float] = (0..<width*width).map{(_)in Float(arc4random())/Float(UInt32.max)}
		var sigma: [Float] = (0..<width*width).map{(_)in Float(arc4random())/Float(UInt32.max)}
		
		let mu_mtl: MTLBuffer = context.newBuffer(mu)
		let sigma_mtl: MTLBuffer = context.newBuffer(sigma)
		
		Bias.gradientInitialize(context: context, grad: (mu_mtl, sigma_mtl), width: width)
		
		mu = context.newBufferFromBuffer(mu_mtl)
		sigma = context.newBufferFromBuffer(sigma_mtl)
		
		context.join()
		
		let mu_la: la_object_t = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(mu), la_count_t(width), la_count_t(width), la_count_t(width), NOHINT, nil, ATTR)
		let sigma_la: la_object_t = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(sigma), la_count_t(width), la_count_t(width), la_count_t(width), NOHINT, nil, ATTR)
		
		let rand: la_object_t = la_matrix_from_float_buffer((0..<width*width).map{(_)in Float(arc4random())}, la_count_t(width), la_count_t(width), la_count_t(width), NOHINT, ATTR)
		XCTAssert(0==la_norm_as_float(la_difference(rand, la_matrix_product(la_transpose(mu_la), rand)), la_norm_t(LA_L2_NORM)))
		XCTAssert(0==la_norm_as_float(la_difference(rand, la_matrix_product(la_transpose(sigma_la), rand)), la_norm_t(LA_L2_NORM)))
	}
	func testCorrect() {
		
		let η: Float = 0.5
		
		let i_width: Int = 8
		let o_width: Int = 8
		
		var logμ: [Float] = (0..<i_width).map{(_)in 0.0+1.0*(Float(arc4random())+1.0)/(Float(UInt32.max)+1.0)}
		var logσ: [Float] = (0..<i_width).map{(_)in 0.0+1.0*(Float(arc4random())+1.0)/(Float(UInt32.max)+1.0)}
		
		let μ: [Float] = logμ.map{$0}
		let σ: [Float] = logσ.map{log(1.0+exp($0))}
		
		let Δμ: [Float] = (0..<o_width).map{(_)in 0.0+1.0*(Float(arc4random())+1.0)/(Float(UInt32.max)+1.0)}
		let Δσ: [Float] = (0..<o_width).map{(_)in 0.0+1.0*(Float(arc4random())+1.0)/(Float(UInt32.max)+1.0)}
		
		let dμ: [Float] = (0..<o_width*i_width).map{(_)in 1.0+0.0*(Float(arc4random())+1.0)/(Float(UInt32.max)+1.0)}
		let dσ: [Float] = (0..<o_width*i_width).map{(_)in 1.0+0.0*(Float(arc4random())+1.0)/(Float(UInt32.max)+1.0)}
		
		let logμ_mtl: MTLBuffer = context.newBufferFromRowMajorMatrix(logμ, rows: i_width, cols: 1)
		let logσ_mtl: MTLBuffer = context.newBufferFromRowMajorMatrix(logσ, rows: i_width, cols: 1)
		
		let μ_mtl: MTLBuffer = context.newBufferFromRowMajorMatrix(μ, rows: i_width, cols: 1)
		let σ_mtl: MTLBuffer = context.newBufferFromRowMajorMatrix(σ, rows:i_width, cols: 1)
		
		let Δμ_mtl: MTLBuffer = context.newBufferFromRowMajorMatrix(Δμ, rows: o_width, cols: 1)
		let Δσ_mtl: MTLBuffer = context.newBufferFromRowMajorMatrix(Δσ, rows: o_width, cols: 1)
		
		let dμ_mtl: MTLBuffer = context.newBufferFromRowMajorMatrix(dμ, rows: o_width, cols: i_width)
		let dσ_mtl: MTLBuffer = context.newBufferFromRowMajorMatrix(dσ, rows: o_width, cols: i_width)
		
		for i in 0..<i_width {
			var m: Float = 0
			var s: Float = 0
			for o in 0..<o_width {
				m += dμ[o*i_width+i] * Δμ[o]
				s += dσ[o*i_width+i] * Δσ[o]
			}
			logμ[i] += η * m
			logσ[i] += η * ( 1 - exp(-σ[i]) ) * s
		}
		
		Bias.correct(context: context, η: η, bias: (logμ_mtl, logσ_mtl, μ_mtl, σ_mtl), grad: (dμ_mtl, dσ_mtl), Δ: (Δμ_mtl, Δσ_mtl), width: o_width)
		
		let dstLogμ: [Float] = context.newRowMajorMatrixFromBuffer(logμ_mtl, rows: i_width, cols: 1)
		let dstLogσ: [Float] = context.newRowMajorMatrixFromBuffer(logσ_mtl, rows: i_width, cols: 1)
		
		context.join()
		
		let μRMSE: Float = zip(logμ, dstLogμ).map { ( $0.0 - $0.1 ) * ( $0.0 - $0.1 ) }.reduce(0) { $0.0 + $0.1 } / Float(i_width)
		
		XCTAssert(!isinf(μRMSE))
		XCTAssert(!isnan(μRMSE))
		
		if 1e-7 < μRMSE {
			print(dstLogμ)
			print(logμ)
			XCTFail("muRMSE: \(μRMSE)")
		}
		
		let σRMSE: Float = zip(logσ, dstLogσ).map { ( $0.0 - $0.1 ) * ( $0.0 - $0.1 ) }.reduce(0) { $0.0 + $0.1 } / Float(i_width)
		
		XCTAssert(!isinf(σRMSE))
		XCTAssert(!isnan(σRMSE))
		
		if 1e-7 < σRMSE {
			XCTFail("muRMSE: \(σRMSE)")
		}
		
	}
	/*
	func testCorrectLightWeight() {
		guard let bias: Bias = context.new() else {
			XCTFail()
			return
		}
		let eps: Float = 0.5
		
		let rows: Int = 16
		let cols: Int = 1
		
		let mu: Float = Float(1+arc4random_uniform(255))/256.0
		let muGrad: Float = 1
		
		let sigma: Float = 1.0 + 0.0 * Float(1+arc4random_uniform(255))/Float(256.0)
		let sigmaGrad: Float = sigma
		
		bias.resize(rows: rows, cols: cols)
		bias.adjust(mu: mu, sigma: sigma)
		
		let dMu: [Float] = (0..<rows*cols).map{(_)in 0.0 + 1.0 * Float(arc4random())/Float(UInt32.max)}
		let dSigma: [Float] = (0..<rows*cols).map{(_)in 1.0 + 0.0 * Float(arc4random())/Float(UInt32.max)}
		
		let mtl_mu: MTLBuffer = context.newBuffer(dMu, options: .StorageModePrivate)
		let mtl_sigma: MTLBuffer = context.newBuffer(dSigma, options: .StorageModePrivate)
		
		bias.correct(eps: eps, delta: (mtl_mu, mtl_sigma))
		bias.refresh()
		
		let srcMu: la_object_t = context.newLaObjectFromBuffer(bias.mu, rows: rows, cols: cols)
		let srcSigma: la_object_t = context.newLaObjectFromBuffer(bias.sigma, rows: rows, cols: cols)

		let dstMu: la_object_t = la_matrix_from_float_buffer(dMu.map { mu + muGrad * eps * $0 }, la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		let dstSigma: la_object_t = la_matrix_from_float_buffer(dSigma.map { sigmaF ( sigmaI ( sigma ) + sigmaG( sigma ) * eps * $0) }, la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		
		context.join()
		
		let rmseMu: Float = la_norm_as_float(la_difference(srcMu, dstMu), L2)
		XCTAssert(!isnan(rmseMu))
		XCTAssert(!isinf(rmseMu))
		
		if 1e-5 < rmseMu {
			XCTFail("\(rmseMu)\r\n\(srcMu.eval)\r\n\(dstMu.eval)\r\n")
		}
		
		let rmseSigma: Float = la_norm_as_float(la_difference(srcSigma, dstSigma), L2)
		XCTAssert(!isnan(rmseSigma))
		XCTAssert(!isinf(rmseSigma))
		
		if 1e-5 < rmseSigma {
			XCTFail("\(rmseSigma)\r\n\(srcSigma.eval)\r\n\(dstSigma.eval)\r\n")
		}
				
	}
*/
}
*/
*/