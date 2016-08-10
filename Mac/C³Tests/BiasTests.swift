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
		//bias.collect(value: value, mean: mean, variance: variance)
		
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
		let rows: Int = 16
		let cols: Int = 1
		
		let mean: Float = Float(1+arc4random_uniform(256))/128.0 - 1.0
		let variance: Float = Float(1+arc4random_uniform(256))/Float(256.0)
		
		let srcMean: [Float] = (0..<rows).map{(_)in Float(arc4random())/Float(UInt32.max)}
		let srcLogvar: [Float] = (0..<rows).map{(_)in Float(arc4random())/Float(UInt32.max)}
		let srcVariance: [Float] = srcLogvar.map{exp($0)}
		
		let dMean: [Float] = (0..<rows).map{(_)in Float(arc4random())/Float(UInt32.max)}
		let dVariance: [Float] = (0..<rows).map{(_)in Float(arc4random())/Float(UInt32.max)}
		
		let mtl_mean: MTLBuffer = context.newBuffer(dMean)
		let mtl_variance: MTLBuffer = context.newBuffer(dVariance)
		
		bias.resize(rows: rows, cols: cols)
		bias.adjust(mean: mean, variance: variance)
		bias.refresh()
		//bias.correctFF(eps: eps, mean: mtl_mean, variance: mtl_variance)
		
		let srcMean_la = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(srcMean), la_count_t(rows), 1, 1, NOHINT, nil, ATTR)
		let dMean_la = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(dMean), la_count_t(rows), 1, 1, NOHINT, nil, ATTR)
		let dstMean_la = la_sum(srcMean_la, la_scale_with_float(dMean_la, eps))
		let obsMean_la = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(bias.mean.contents()), la_count_t(rows), 1, 1, NOHINT, nil, ATTR)
		let errMean_la = la_difference(dstMean_la, obsMean_la)

		let srcLogvar_la = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(srcLogvar), la_count_t(rows), 1, 1, NOHINT, nil, ATTR)
		let srcVariance_la = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(srcVariance), la_count_t(rows), 1, 1, NOHINT, nil, ATTR)
		let dVariance_la = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(dVariance), la_count_t(rows), 1, 1, NOHINT, nil, ATTR)
		let dstLogvar_la = la_difference(srcLogvar_la, la_scale_with_float(la_elementwise_product(dVariance_la, srcVariance_la), 0.5*eps))
		let obsLogvar_la = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(bias.logvariance.contents()), la_count_t(rows), 1, 1, NOHINT, nil, ATTR)
		let errLogvar_la = la_difference(dstLogvar_la, obsLogvar_la)
		
		context.join()
		
		let rmseMean: Float = la_norm_as_float(errMean_la, la_norm_t(LA_L2_NORM))/Float(rows)
		if 1e-7 < rmseMean {
			XCTFail("RMSE: \(rmseMean)")
		}
		
		let rmseLogvariance: Float = la_norm_as_float(errLogvar_la, la_norm_t(LA_L2_NORM))/Float(rows)
		if 1e-7 < rmseLogvariance {
			let cache: [Float] = [Float](count: rows, repeatedValue: 0.0)
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), 1, srcLogvar_la)
			print("SRC: \(cache)")
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), 1, dVariance_la)
			print("DELTA: \(cache)")
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), 1, dstLogvar_la)
			print("DST: \(cache)")
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), 1, obsLogvar_la)
			print("OBSERVE: \(cache)")
			XCTFail("RMSE: \(rmseLogvariance)")
		}
		
	}
}
