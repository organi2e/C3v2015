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

class BiasTests: XCTestCase {
	
	let context: Context = try!Context()
	let NOHINT: la_hint_t = la_hint_t(LA_NO_HINT)
	let ATTR: la_attribute_t = la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)
	
	func testCollect() {
		guard let bias: Bias = context.new() else {
			XCTFail()
			return
		}
		let rows: Int = 256
		let cols: Int = 1
		
		let value: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows)
		let mean: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows)
		let variance: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows)
		
		context.newBlitCommand {(let encoder: MTLBlitCommandEncoder)in
			[value, mean, variance].forEach {
				encoder.fillBuffer($0, range: NSRange(location: 0, length: $0.length), value: 0)
			}
		}
		
		bias.resize(rows: rows, cols: cols)
		bias.refresh()
		bias.collect((value, mean, variance))
		
		let srcValue: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(bias.value.contents()), count: rows)
		let srcMean: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(bias.mean.contents()), count: rows)
		let srcVariance: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(bias.variance.contents()), count: rows)
		
		let dstValue: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(value.contents()), count: rows)
		let dstMean: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(mean.contents()), count: rows)
		let dstVariance: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(variance.contents()), count: rows)

		context.join()

		XCTAssert(srcValue.elementsEqual(dstValue))
		XCTAssert(srcMean.elementsEqual(dstMean))
		XCTAssert(srcVariance.elementsEqual(dstVariance))
		
	}
	func testCorrectFF() {
		guard let bias: Bias = context.new() else {
			XCTFail()
			return
		}
		let eps: Float = 0.5
		let width: Int = 4
		
		let mean: Float = Float(1+arc4random_uniform(255))/128.0 - 1.0
		let variance: Float = Float(1+arc4random_uniform(255))/Float(256.0)
		
		bias.resize(rows: width, cols: 1)
		bias.adjust(mean: mean, variance: variance)
		
		let dMean: [Float] = (0..<width).map{(_)in Float(arc4random())/Float(UInt32.max)}
		let dVariance: [Float] = (0..<width).map{(_)in Float(arc4random())/Float(UInt32.max)}
		
		let mtl_mean: MTLBuffer = context.newBuffer(dMean)
		let mtl_variance: MTLBuffer = context.newBuffer(dVariance)
		
		bias.refresh()
		bias.correctFF(eps, delta: (mtl_mean, mtl_variance))
		bias.refresh()
		
		let dstMean_la: la_object_t = la_matrix_from_float_buffer(dMean.map{ tanh(-0.5*log(2.0/(mean+1.0)-1.0) + eps * ( 1.0 - mean * mean ) * $0 ) }, la_count_t(width), 1, 1, NOHINT, ATTR)
		let dstVariance_la: la_object_t = la_matrix_from_float_buffer(dVariance.map { exp( log(variance) + eps * (variance) * $0 ) }, la_count_t(width), 1, 1, NOHINT, ATTR)
		
		let obsMean_la = context.toLAObject(bias.mean, rows: width, cols: 1)
		let obsVariance_la = context.toLAObject(bias.variance, rows: width, cols: 1)
		
		let errMean_la = la_difference(dstMean_la, obsMean_la)
		let errVariance_la = la_difference(dstVariance_la, obsVariance_la)
		
		context.join()
		
		let rmseMean: Float = la_norm_as_float(errMean_la, la_norm_t(LA_L2_NORM))/sqrt(Float(width))
		if 1e-7 < rmseMean {
			let cache: [Float] = [Float](count: width, repeatedValue: mean)
			print("SRC: \(cache)")
			print("DELTA: \(dMean)")
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), 1, dstMean_la)
			print("DST: \(cache)")
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), 1, obsMean_la)
			print("OBS: \(cache)")
			XCTFail("RMSE: \(rmseMean)")
		}
		
		let rmseLogvariance: Float = la_norm_as_float(errVariance_la, la_norm_t(LA_L2_NORM))/sqrt(Float(width))
		if 1e-7 < rmseLogvariance {
			let cache: [Float] = [Float](count: width, repeatedValue: variance)
			print("SRC: \(cache)")
			print("DELTA: \(dVariance)")
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), 1, dstVariance_la)
			print("DST: \(cache)")
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), 1, obsVariance_la)
			print("OBS: \(cache)")
			XCTFail("RMSE: \(rmseLogvariance)")
		}
		
	}
}
