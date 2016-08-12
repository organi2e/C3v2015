//
//  ComputerTests.swift
//  Mac
//
//  Created by Kota Nakano on 6/7/16.
//
//
import Accelerate
import XCTest
@testable import C3

class EdgeTests: XCTestCase {
	let context: Context = try!Context()
	let NOHINT: la_hint_t = la_hint_t(LA_NO_HINT)
	let ATTR: la_attribute_t = la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)
	func uniform(let count: Int) -> [Float] {
		let result: [Float] = [Float](count: count, repeatedValue: 0.0)
		arc4random_buf(UnsafeMutablePointer<Void>(result), sizeof(Float)*result.count)
		vDSP_vfltu32(UnsafePointer<UInt32>(result), 1, UnsafeMutablePointer<Float>(result), 1, vDSP_Length(count))
		vDSP_vsadd(UnsafePointer<Float>(result), 1, [Float(1.0)], UnsafeMutablePointer<Float>(result), 1, vDSP_Length(count))
		vDSP_vsdiv(UnsafePointer<Float>(result), 1, [Float(UInt32.max)], UnsafeMutablePointer<Float>(result), 1, vDSP_Length(count))
		return result;
	}
	func dump(let buffer: la_object_t) {
		let rows: Int = Int(la_matrix_rows(buffer))
		let cols: Int = Int(la_matrix_cols(buffer))
		let cache: [Float] = [Float](count: rows*cols, repeatedValue: 0.0)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(cols), buffer)
		(0..<rows).forEach {
			print(cache[$0*cols..<$0*cols+cols])
		}
	}
	func dump(let buffer: MTLBuffer, let rows: Int, let cols: Int) {
		let matrix: la_object_t = context.toLAObject(buffer, rows: rows, cols: cols)
		context.join()
		dump(matrix)
	}
	func testCollect() {
		
		let rows: Int = 1024
		let cols: Int = 1024
		
		let state_la: la_object_t = la_matrix_from_float_buffer(uniform(cols), la_count_t(cols), la_count_t(1), la_count_t(1), NOHINT, ATTR)
		let state_mtl: MTLBuffer = context.fromLAObject(state_la)
		
		let edge_la = (
			value: la_matrix_from_float_buffer(uniform(rows*cols), la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR),
			mean: la_matrix_from_float_buffer(uniform(rows*cols), la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR),
			variance: la_matrix_from_float_buffer(uniform(rows*cols), la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		)
		
		let edge_mtl = (
			value: context.fromLAObject(edge_la.value),
			mean: context.fromLAObject(edge_la.mean),
			variance: context.fromLAObject(edge_la.variance)
		)
		
		let level_mtl = (
			value: context.newBuffer(length: sizeof(Float)*rows),
			mean: context.newBuffer(length: sizeof(Float)*rows),
			variance: context.newBuffer(length: sizeof(Float)*rows)
		)

		measureBlock {
			Edge.collect(context: self.context, level: level_mtl, edge: edge_mtl, state: state_mtl, rows: rows, cols: cols)
			self.context.join()
		}
		
		let level_mtl_la = (
			value: context.toLAObject(level_mtl.value, rows: rows, cols: 1),
			mean: context.toLAObject(level_mtl.mean, rows: rows, cols: 1),
			variance: context.toLAObject(level_mtl.variance, rows: rows, cols: 1)
		)
		
		let level_la = (
			value: la_matrix_product(edge_la.value, state_la),
			mean: la_matrix_product(edge_la.mean, state_la),
			variance: la_matrix_product(edge_la.variance, la_elementwise_product(state_la, state_la))
		)
		
		context.join()
		
		let rmse_value: Float = la_norm_as_float(la_difference(level_mtl_la.value, level_la.value), la_norm_t(LA_L2_NORM)) / sqrt(Float(rows))
		if 1e-4 < rmse_value {
			XCTFail("RMSE: \(rmse_value)")
		}
		
		let rmse_mean: Float = la_norm_as_float(la_difference(level_mtl_la.mean, level_la.mean), la_norm_t(LA_L2_NORM)) / sqrt(Float(rows))
		if 1e-4 < rmse_value {
			XCTFail("RMSE: \(rmse_mean)")
		}
		
		let rmse_variance: Float = la_norm_as_float(la_difference(level_mtl_la.variance, level_la.variance), la_norm_t(LA_L2_NORM)) / sqrt(Float(rows))
		if 1e-4 < rmse_value {
			XCTFail("RMSE: \(rmse_variance)")
		}
		
	}
	func testCorrectFF() {
		
		let o_width: Int = 256
		let i_width: Int = 256
		
		var logmean: [Float] = uniform(o_width*i_width)
		var logvariance: [Float] = uniform(o_width*i_width)
		
		let mean: [Float] = logmean.map{tanh($0)}
		let variance: [Float] = logvariance.map{exp($0)}
		
		let edge = (
			logmean: logmean,
			logvariance: logvariance,
			mean: mean,
			variance: variance
		)
		
		var error: [Float] = uniform(i_width)
		let state: [Float] = uniform(i_width)

		let error_la: la_object_t = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(error), la_count_t(i_width), 1, 1, NOHINT, nil, ATTR)
		let state_la: la_object_t = la_matrix_from_float_buffer(state, la_count_t(i_width), 1, 1, NOHINT, ATTR)
		
		let error_mtl: MTLBuffer = context.fromLAObject(error_la)
		let state_mtl: MTLBuffer = context.fromLAObject(state_la)
		
		let delta = (
			mean: uniform(o_width),
			variance: uniform(o_width)
		)
		let delta_la = (
			mean: la_matrix_from_float_buffer(delta.mean, la_count_t(o_width), 1, 1, NOHINT, ATTR),
			variance: la_matrix_from_float_buffer(delta.variance, la_count_t(o_width), 1, 1, NOHINT, ATTR)
		)
		let delta_mtl = (
			mean: context.fromLAObject(delta_la.mean),
			variance: context.fromLAObject(delta_la.variance)
		)
		
		let edge_la = (
			logmean: la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(edge.logmean), la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, nil, ATTR),
			logvariance: la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(edge.logvariance), la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, nil, ATTR),
			mean: la_matrix_from_float_buffer(edge.mean, la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR),
			variance: la_matrix_from_float_buffer(edge.variance, la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR)
		)
		
		let edge_mtl = (
			logmean: context.fromLAObject(edge_la.logmean),
			logvariance: context.fromLAObject(edge_la.logvariance),
			mean: context.fromLAObject(edge_la.mean),
			variance: context.fromLAObject(edge_la.variance)
		)
		
		let eps: Float = 0.5
		
		Edge.correctFF(context: context, eps: eps, error: error_mtl, edge: edge_mtl, state: state_mtl, delta: delta_mtl, rows: o_width, cols: i_width)
		
		let obsError_la: la_object_t = context.toLAObject(error_mtl, rows: i_width, cols: 1)
		let obsLogmean_la: la_object_t = context.toLAObject(edge_mtl.logmean, rows: o_width, cols: i_width)
		let obsLogvariance_la: la_object_t = context.toLAObject(edge_mtl.logvariance, rows: o_width, cols: i_width)
		
		for i in 0..<i_width {
			var accum: Float = 0.0
			for o in 0..<o_width {
				accum += edge.mean[o*i_width+i] * delta.mean[o]
				accum += edge.variance[o*i_width+i] * delta.variance[o] *
				logmean[o*i_width+i] += eps * ( 1 - mean[o*i_width+i] * mean[o*i_width+i] ) * state[i] * delta.mean[o]
				logvariance[o*i_width+i] += eps * variance[o*i_width+i] * state[i] * delta.mean[o]
			}
			error[i] = accum
		}
		
		context.join()
		
		let rmseError: Float = la_norm_as_float(la_difference(error_la, obsError_la), la_norm_t(LA_L2_NORM)) / sqrt(Float(i_width))
		XCTAssert(!isnan(rmseError))
		XCTAssert(!isinf(rmseError))
		if 1e-4 < rmseError {
			XCTFail("RMSE: \(rmseError)")
		}
		
		let rmseLogmean: Float = la_norm_as_float(la_difference(edge_la.logmean, obsLogmean_la), la_norm_t(LA_L2_NORM)) / sqrt(Float(o_width*i_width))
		XCTAssert(!isnan(rmseLogmean))
		XCTAssert(!isinf(rmseLogmean))
		if 1e-4 < rmseLogmean {
			XCTFail("RMSE: \(rmseLogmean)")
		}
		
		let rmseLogvariance: Float = la_norm_as_float(la_difference(edge_la.logvariance, obsLogvariance_la), la_norm_t(LA_L2_NORM)) / sqrt(Float(o_width*i_width))
		XCTAssert(!isnan(rmseLogvariance))
		XCTAssert(!isinf(rmseLogvariance))
		if 1e-4 < rmseLogvariance {
			XCTFail("RMSE: \(rmseLogvariance)")
		}
		
	}
}

