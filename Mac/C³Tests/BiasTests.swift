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
		
		let value: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows*cols, options: .StorageModePrivate)
		let mu: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows*cols, options: .StorageModePrivate)
		let sigma: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows*cols, options: .StorageModePrivate)
		
		context.newBlitCommand {(let encoder: MTLBlitCommandEncoder)in
			[value, mu, sigma].forEach {
				encoder.fillBuffer($0, range: NSRange(location: 0, length: $0.length), value: 0)
			}
		}
		
		bias.resize(rows: rows, cols: cols)
		bias.adjust(mu: 0.5, sigma: 1.0)
		bias.refresh()
		bias.shuffle()
		bias.collect(level: (value, mu, sigma))
		
		let srcValue: la_object_t = context.toLAObject(bias.value, rows: rows, cols: cols)
		let dstValue: la_object_t = context.toLAObject(value, rows: rows, cols: cols)
		
		let srcMu: la_object_t = context.toLAObject(bias.mu, rows: rows, cols: cols)
		let dstMu: la_object_t = context.toLAObject(mu, rows: rows, cols: cols)
		
		let srcSigma: la_object_t = context.toLAObject(bias.sigma, rows: rows, cols: cols)
		let dstSigma: la_object_t = context.toLAObject(sigma, rows: rows, cols: cols)
		
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
	func testCorrectFF() {
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
		
		bias.correctFF(eps: eps, delta: (mtl_mu, mtl_sigma))
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
}
