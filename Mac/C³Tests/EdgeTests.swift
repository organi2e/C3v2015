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

func muGrad(value: Float) -> Float {
	return 1.0
}
func sigmaGrad(value: Float) -> Float {
	return 1.0 - exp( -value )
}

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
			mu: la_matrix_from_float_buffer(uniform(rows*cols), la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR),
			sigma: la_matrix_from_float_buffer(uniform(rows*cols), la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		)
		
		let edge_mtl = (
			value: context.fromLAObject(edge_la.value),
			mu: context.fromLAObject(edge_la.mu),
			sigma: context.fromLAObject(edge_la.sigma)
		)
		
		let level_mtl = (
			value: context.newBuffer(length: sizeof(Float)*rows),
			mu: context.newBuffer(length: sizeof(Float)*rows),
			sigma: context.newBuffer(length: sizeof(Float)*rows)
		)

		measureBlock {
			Edge.collect(context: self.context, level: level_mtl, edge: edge_mtl, state: state_mtl, rows: rows, cols: cols)
			self.context.join()
		}
		
		let level_mtl_la = (
			value: context.toLAObject(level_mtl.value, rows: rows, cols: 1),
			mu: context.toLAObject(level_mtl.mu, rows: rows, cols: 1),
			sigma: context.toLAObject(level_mtl.sigma, rows: rows, cols: 1)
		)
		
		let level_la = (
			value: la_matrix_product(edge_la.value, state_la),
			mu: la_matrix_product(edge_la.mu, state_la),
			sigma: la_matrix_product(edge_la.sigma, la_elementwise_product(state_la, state_la))
		)
		
		context.join()
		
		let rmse_value: Float = la_norm_as_float(la_difference(level_mtl_la.value, level_la.value), la_norm_t(LA_L2_NORM)) / sqrt(Float(rows))
		if 1e-4 < rmse_value {
			XCTFail("RMSE: \(rmse_value)")
		}
		
		let rmse_mu: Float = la_norm_as_float(la_difference(level_mtl_la.mu, level_la.mu), la_norm_t(LA_L2_NORM)) / sqrt(Float(rows))
		if 1e-4 < rmse_value {
			XCTFail("RMSE: \(rmse_mu)")
		}
		
		let rmse_sigma: Float = la_norm_as_float(la_difference(level_mtl_la.sigma, level_la.sigma), la_norm_t(LA_L2_NORM)) / sqrt(Float(rows))
		if 1e-4 < rmse_value {
			XCTFail("RMSE: \(rmse_sigma)")
		}
		
	}
	func testCorrectFF() {
		
		let o_width: Int = 4 * Int(1+arc4random_uniform(255))
		let i_width: Int = 4 * Int(1+arc4random_uniform(255))
		
		let value: [Float] = uniform(o_width*i_width)
		
		var logmu: [Float] = uniform(o_width*i_width)
		var logsigma: [Float] = uniform(o_width*i_width)
		
		let mu: [Float] = logmu.map{tanh($0)}
		let sigma: [Float] = logsigma.map{log(1+exp($0))}
		
		let edge = (
			value: value,
			logmu: logmu,
			logsigma: logsigma,
			mu: mu,
			sigma: sigma
		)
		
		var error: [Float] = uniform(i_width)
		let state: [Float] = uniform(i_width)

		let error_la: la_object_t = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(error), la_count_t(i_width), 1, 1, NOHINT, nil, ATTR)
		let state_la: la_object_t = la_matrix_from_float_buffer(state, la_count_t(i_width), 1, 1, NOHINT, ATTR)
		
		let error_mtl: MTLBuffer = context.fromLAObject(error_la)
		let state_mtl: MTLBuffer = context.fromLAObject(state_la)
		
		let delta = (
			value: uniform(o_width),
			mu: uniform(o_width),
			sigma: uniform(o_width)
		)
		let delta_la = (
			value: la_matrix_from_float_buffer(delta.value, la_count_t(o_width), 1, 1, NOHINT, ATTR),
			mu: la_matrix_from_float_buffer(delta.mu, la_count_t(o_width), 1, 1, NOHINT, ATTR),
			sigma: la_matrix_from_float_buffer(delta.sigma, la_count_t(o_width), 1, 1, NOHINT, ATTR)
		)
		let delta_mtl = (
			value: context.fromLAObject(delta_la.value),
			mu: context.fromLAObject(delta_la.mu),
			sigma: context.fromLAObject(delta_la.sigma)
		)
		
		let edge_la = (
			logmu: la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(edge.logmu), la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, nil, ATTR),
			logsigma: la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(edge.logsigma), la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, nil, ATTR),
			value: la_matrix_from_float_buffer(edge.value, la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR),
			mu: la_matrix_from_float_buffer(edge.mu, la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR),
			sigma: la_matrix_from_float_buffer(edge.sigma, la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR)
		)
		
		let edge_mtl = (
			logmu: context.fromLAObject(edge_la.logmu),
			logsigma: context.fromLAObject(edge_la.logsigma),
			value: context.fromLAObject(edge_la.value),
			mu: context.fromLAObject(edge_la.mu),
			sigma: context.fromLAObject(edge_la.sigma)
		)
		
		let η: Float = 0.5
		
		Edge.correctFF(context: context, η: η, error: error_mtl, edge: edge_mtl, state: state_mtl, Δ: delta_mtl, rows: o_width, cols: i_width)
		
		let obsError_la: la_object_t = context.toLAObject(error_mtl, rows: i_width, cols: 1)
		
		let obsLogmu_la: la_object_t = context.toLAObject(edge_mtl.logmu, rows: o_width, cols: i_width)
		let obsLogsigma_la: la_object_t = context.toLAObject(edge_mtl.logsigma, rows: o_width, cols: i_width)
		
		for i in 0..<i_width {
			var accum: Float = 0.0
			for o in 0..<o_width {
				
				accum += delta.value[o] * edge.value[o * i_width + i]
				//accum += delta.mu[o] * edge.mu[o * i_width + i]
				//accum += delta.sigma[o] * edge.sigma[o * i_width + i] * 2.0 * state[i]
				
				logmu[ o * i_width + i ] += η * muGrad ( mu[o*i_width+i] ) * ( state[i] ) * delta.mu[o]
				logsigma[ o * i_width + i ] += η * sigmaGrad ( sigma[o*i_width+i] ) * ( state[i] * state[i] ) * delta.sigma[o]
				
			}
			error[i] = accum
		}
		
		let dstLogmu_la: la_object_t = la_matrix_from_float_buffer(UnsafePointer<Float>(logmu), la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR)
		let dstLogsigma_la: la_object_t = la_matrix_from_float_buffer(UnsafePointer<Float>(logsigma), la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR)
		
		context.join()
		
		let rmseError: Float = la_norm_as_float(la_difference(error_la, obsError_la), la_norm_t(LA_L2_NORM)) / sqrt(Float(i_width))
		XCTAssert(!isnan(rmseError))
		XCTAssert(!isinf(rmseError))
		if 1e-3 < rmseError {
			print("a")
			dump(error_la)
			print("b")
			dump(obsError_la)
			XCTFail("RMSE: \(rmseError)")
		}
		
		let rmseLogmu: Float = la_norm_as_float(la_difference(dstLogmu_la, obsLogmu_la), la_norm_t(LA_L2_NORM)) / sqrt(Float(o_width*i_width))
		XCTAssert(!isnan(rmseLogmu))
		XCTAssert(!isinf(rmseLogmu))
		if 1e-3 < rmseLogmu {
			print("logmu a")
			dump(dstLogmu_la)
			print("logmu b")
			dump(obsLogmu_la)
			XCTFail("RMSE: \(rmseLogmu)")
		}
		
		let rmseLogsigma: Float = la_norm_as_float(la_difference(dstLogsigma_la, obsLogsigma_la), la_norm_t(LA_L2_NORM)) / sqrt(Float(o_width*i_width))
		XCTAssert(!isnan(rmseLogsigma))
		XCTAssert(!isinf(rmseLogsigma))
		
		if 1e-3 < rmseLogsigma {
			print("logsigma a")
			dump(dstLogsigma_la)
			print("logsigma b")
			dump(obsLogsigma_la)
			XCTFail("RMSE: \(rmseLogsigma)")
		}
		
	}
}

