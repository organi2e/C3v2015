//
//  BlobTests.swift
//  Mac
//
//  Created by Kota Nakano on 7/23/16.
//
//
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
	let NOHINT: la_hint_t = la_hint_t(LA_NO_HINT)
	let ATTR: la_attribute_t = la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)
	let L2: la_norm_t = la_norm_t(LA_L2_NORM)
	
	func testCollect() {
		guard let bias: Bias = context.new() else {
			XCTFail()
			return
		}
		let rows: Int = 256
		let cols: Int = 1
		
		let χ: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows*cols, options: .StorageModePrivate)
		let μ: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows*cols, options: .StorageModePrivate)
		let σ: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows*cols, options: .StorageModePrivate)
		
		context.newBlitCommand {(let encoder: MTLBlitCommandEncoder)in
			[χ, μ, σ].forEach {
				encoder.fillBuffer($0, range: NSRange(location: 0, length: $0.length), value: 0)
			}
		}
		
		//bias.resize(rows: rows, cols: cols)
		bias.adjust(μ: 0.5, σ: 1.0)
		bias.refresh()
		bias.shuffle()
		bias.collect(level: (χ, μ, σ))
		
		let srcValue: la_object_t = context.toLAObject(bias.χ, rows: rows, cols: cols)
		let dstValue: la_object_t = context.toLAObject(χ, rows: rows, cols: cols)
		
		let srcMu: la_object_t = context.toLAObject(bias.μ, rows: rows, cols: cols)
		let dstMu: la_object_t = context.toLAObject(μ, rows: rows, cols: cols)
		
		let srcSigma: la_object_t = context.toLAObject(bias.σ, rows: rows, cols: cols)
		let dstSigma: la_object_t = context.toLAObject(σ, rows: rows, cols: cols)
		
		context.join()
		
		let errValue: Float = la_norm_as_float(la_difference(srcValue, dstValue), L2)
		let errMu: Float = la_norm_as_float(la_difference(srcMu, dstMu), L2)
		let errSigma: Float = la_norm_as_float(la_difference(srcSigma, dstSigma), L2)

		XCTAssert(!isinf(errValue))
		XCTAssert(!isnan(errValue))
		
		if 1e-7 < errValue {
			XCTFail("\(errValue)")
		}
		
		XCTAssert(!isinf(errMu))
		XCTAssert(!isnan(errMu))
		
		if 1e-7 < errMu {
			XCTFail("\(errMu)")
		}
		
		XCTAssert(!isinf(errSigma))
		XCTAssert(!isnan(errSigma))
		
		if 1e-7 < errSigma {
			XCTFail("\(errSigma)")
		}
		
	}
	func testGradientEye() {
		let width: Int = 16
		let rows: Int = 16
		let cols: Int = 16
		let mu: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows*cols)
		let sigma: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows*cols)
		Bias.gradientEye(context: context, grad: (mu, sigma), width: width)
		let mu_la: la_object_t = context.toLAObject(mu, rows: rows, cols: cols)
		let sigma_la: la_object_t = context.toLAObject(sigma, rows: rows, cols: cols)
		context.join()
		let rand: la_object_t = la_matrix_from_float_buffer((0..<rows*cols).map{(_)in Float(arc4random())}, la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		XCTAssert(0<la_norm_as_float(la_difference(rand, la_matrix_product(mu_la, rand)), la_norm_t(LA_L2_NORM)))
		XCTAssert(0<la_norm_as_float(la_difference(rand, la_matrix_product(sigma_la, rand)), la_norm_t(LA_L2_NORM)))
	}
	func testCorrect() {
		
		let η: Float = 0.5
		
		let i_width: Int = 16
		let o_width: Int = 16
		
		var logμ: [Float] = (0..<i_width).map{(_)in (Float(arc4random())+1.0)/(Float(UInt32.max)+1.0)}
		var logσ: [Float] = (0..<i_width).map{(_)in (Float(arc4random())+1.0)/(Float(UInt32.max)+1.0)}
		
		let μ: [Float] = logμ.map{$0}
		let σ: [Float] = logσ.map{log(1.0+exp($0))}
		
		let Δμ: [Float] = (0..<o_width).map{(_)in (Float(arc4random())+1.0)/(Float(UInt32.max)+1.0)}
		let Δσ: [Float] = (0..<o_width).map{(_)in (Float(arc4random())+1.0)/(Float(UInt32.max)+1.0)}
		
		let dμ: [Float] = (0..<o_width*i_width).map{(_)in (Float(arc4random())+1.0)/(Float(UInt32.max)+1.0)}
		let dσ: [Float] = (0..<o_width*i_width).map{(_)in (Float(arc4random())+1.0)/(Float(UInt32.max)+1.0)}
		
		let logμ_mtl: MTLBuffer = context.fromRowMajorMatrix(logμ, rows: i_width, cols: 1)
		let logσ_mtl: MTLBuffer = context.fromRowMajorMatrix(logσ, rows: i_width, cols: 1)
		
		let μ_mtl: MTLBuffer = context.fromRowMajorMatrix(μ, rows: i_width, cols: 1)
		let σ_mtl: MTLBuffer = context.fromRowMajorMatrix(σ, rows:i_width, cols: 1)
		
		let Δμ_mtl: MTLBuffer = context.fromRowMajorMatrix(Δμ, rows: o_width, cols: 1)
		let Δσ_mtl: MTLBuffer = context.fromRowMajorMatrix(Δσ, rows: o_width, cols: 1)
		
		let dμ_mtl: MTLBuffer = context.fromRowMajorMatrix(dμ, rows: o_width, cols: i_width)
		let dσ_mtl: MTLBuffer = context.fromRowMajorMatrix(dσ, rows: o_width, cols: i_width)
		
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
		
		let dstLogμ: [Float] = context.toRowMajorMatrix(logμ_mtl, rows: i_width, cols: 1)
		let dstLogσ: [Float] = context.toRowMajorMatrix(logσ_mtl, rows: i_width, cols: 1)
		
		context.join()
		
		let μRMSE: Float = zip(logμ, dstLogμ).map { ( $0.0 - $0.1 ) * ( $0.0 - $0.1 ) }.reduce(0) { $0.0 + $0.1 } / Float(i_width)
		
		XCTAssert(!isinf(μRMSE))
		XCTAssert(!isnan(μRMSE))
		
		if 1e-7 < μRMSE {
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
		
		let srcMu: la_object_t = context.toLAObject(bias.mu, rows: rows, cols: cols)
		let srcSigma: la_object_t = context.toLAObject(bias.sigma, rows: rows, cols: cols)

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
