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
	
		let i_rows: Int = 4 * Int(1+arc4random_uniform(256))
		let o_rows: Int = 4 * Int(1+arc4random_uniform(256))
		
		let input: Cell = try!context.newCell(width: i_rows)
		let output: Cell = try!context.newCell(width: o_rows)
		
		guard let edge: Edge = context.new() else {
			XCTFail()
			return
		}
		
		edge.resize(rows: o_rows, cols: i_rows)
		edge.adjust(mean: 0.0, variance: 1/Float(i_rows))
		edge.input = input
		edge.output = output
		edge.setup()
		edge.refresh()
		
		input.oClear()
		output.iClear()
		
		let value: MTLBuffer = context.newBuffer([Float](count: o_rows, repeatedValue: 0.0))
		let mean: MTLBuffer = context.newBuffer([Float](count: o_rows, repeatedValue: 0.0))
		let variance: MTLBuffer = context.newBuffer([Float](count: o_rows, repeatedValue: 0.0))
		
		input.active = (0..<i_rows).map{(_)in arc4random_uniform(2) % 2 != 0}
		//edge.collect(value: value, mean: mean, variance: variance, visit: [])
		
		let input_state: la_object_t = context.toLAObject(input.state[0].value, rows: i_rows, cols: 1)
		
		context.join()
		
		let edge_value: la_object_t = context.toLAObject(edge.value, rows: o_rows, cols: i_rows)
		let edge_mean: la_object_t = context.toLAObject(edge.mean, rows: o_rows, cols: i_rows)
		let edge_variance: la_object_t = context.toLAObject(edge.variance, rows: o_rows, cols: i_rows)
		
		context.join()
		
		let output_value: la_object_t = la_matrix_product(edge_value, input_state)
		let output_mean: la_object_t = la_matrix_product(edge_mean, input_state)
		let output_variance: la_object_t = la_matrix_product(edge_variance, la_elementwise_product(input_state, input_state))
		
		context.join()
		
		let ob_value: la_object_t = context.toLAObject(value, rows: o_rows, cols: 1)
		let ob_mean: la_object_t = context.toLAObject(mean, rows: o_rows, cols: 1)
		let ob_variance: la_object_t = context.toLAObject(variance, rows: o_rows, cols: 1)
		
		context.join()
		
		let rmse_value: Float = la_norm_as_float(la_difference(output_value, ob_value), la_norm_t(LA_L2_NORM)) / sqrt(Float(o_rows))
		if 1e-3 < rmse_value {
			//print("output")
			//dump(la_transpose(output_value))
			//print("observe")
			//dump(la_transpose(ob_value))
			print("edge")
			dump(edge.value, rows: o_rows, cols: i_rows)
			XCTFail("RMSE: \(rmse_value)")
		}
		let rmse_mean: Float = la_norm_as_float(la_difference(output_mean, ob_mean), la_norm_t(LA_L2_NORM)) / sqrt(Float(o_rows))
		if 1e-4 < rmse_mean {
			XCTFail("RMSE: \(rmse_mean)")
		}
		let rmse_variance: Float = la_norm_as_float(la_difference(output_variance, ob_variance), la_norm_t(LA_L2_NORM)) / sqrt(Float(o_rows))
		if 1e-4 < rmse_variance {
			XCTFail("RMSE: \(rmse_variance)")
		}
		
	}
	func testCollectWithPrimitive() {
		let rows: Int = 1024
		let cols: Int = 1024
		let value: la_object_t = la_matrix_from_float_buffer(uniform(rows*cols), la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		let mean: la_object_t = la_matrix_from_float_buffer(uniform(rows*cols), la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		let variance: la_object_t = la_matrix_from_float_buffer(uniform(rows*cols), la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		let state: la_object_t = la_matrix_from_float_buffer(uniform(cols), la_count_t(cols), la_count_t(1), la_count_t(1), NOHINT, ATTR)
		let cache: [Float] = [Float](count: rows, repeatedValue: 0.0)
		
		measureBlock {
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(1), la_matrix_product(value, state))
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(1), la_matrix_product(mean, state))
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(1), la_matrix_product(variance, la_elementwise_product(state, state)))
		}
		
	}
	func testCollectWithMacro() {
		
		let rows: Int = 1024
		let cols: Int = 1024
		
		let la_edge_value: la_object_t = la_matrix_from_float_buffer(uniform(rows*cols), la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		let la_edge_mean: la_object_t = la_matrix_from_float_buffer(uniform(rows*cols), la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		let la_edge_variance: la_object_t = la_matrix_from_float_buffer(uniform(rows*cols), la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		
		let la_input_state: la_object_t = la_matrix_from_float_buffer(uniform(cols), la_count_t(cols), la_count_t(1), la_count_t(1), NOHINT, ATTR)
		
		let mtl_edge_value: MTLBuffer = context.fromLAObject(la_edge_value)
		let mtl_edge_mean: MTLBuffer = context.fromLAObject(la_edge_mean)
		let mtl_edge_variance: MTLBuffer = context.fromLAObject(la_edge_variance)
		
		let mtl_input_state: MTLBuffer = context.fromLAObject(la_input_state)
		
		let mtl_level_value: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows)
		let mtl_level_mean: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows)
		let mtl_level_variance: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows)
		
		measureBlock {
			
			self.context.join()
		}
		
		let la_mtl_level_value: la_object_t = context.toLAObject(mtl_level_value, rows: rows, cols: 1)
		let la_mtl_level_mean: la_object_t = context.toLAObject(mtl_level_mean, rows: rows, cols: 1)
		let la_mtl_level_variance: la_object_t = context.toLAObject(mtl_level_variance, rows: rows, cols: 1)
		
		let la_level_value: la_object_t = la_matrix_product(la_edge_value, la_input_state)
		let la_level_mean: la_object_t = la_matrix_product(la_edge_mean, la_input_state)
		let la_level_variance: la_object_t = la_matrix_product(la_edge_variance, la_elementwise_product(la_input_state, la_input_state))
		
		context.join()
		
		let rmse_value: Float = la_norm_as_float(la_difference(la_mtl_level_value, la_level_value), la_norm_t(LA_L2_NORM)) / sqrt(Float(rows))
		if 1e-4 < rmse_value {
			XCTFail("RMSE: \(rmse_value)")
		}
		
		let rmse_mean: Float = la_norm_as_float(la_difference(la_mtl_level_mean, la_level_mean), la_norm_t(LA_L2_NORM)) / sqrt(Float(rows))
		if 1e-4 < rmse_value {
			XCTFail("RMSE: \(rmse_mean)")
		}
		
		let rmse_variance: Float = la_norm_as_float(la_difference(la_mtl_level_variance, la_level_variance), la_norm_t(LA_L2_NORM)) / sqrt(Float(rows))
		if 1e-4 < rmse_value {
			XCTFail("RMSE: \(rmse_variance)")
		}
		
	}
	func testCorrectFF() {
		let rows: Int = 1024
		let cols: Int = 1024
		
		let la_edge_value: la_object_t = la_matrix_from_float_buffer(uniform(rows*cols), la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		let la_edge_mean: la_object_t = la_matrix_from_float_buffer(uniform(rows*cols), la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		let la_edge_logvariance: la_object_t = la_matrix_from_float_buffer(uniform(rows*cols), la_count_t(rows), la_count_t(cols), la_count_t(cols), NOHINT, ATTR)
		
		let la_input_state: la_object_t = la_matrix_from_float_buffer(uniform(cols), la_count_t(cols), la_count_t(1), la_count_t(1), NOHINT, ATTR)
		
		let mtl_edge_value: MTLBuffer = context.fromLAObject(la_edge_value)
		let mtl_edge_mean: MTLBuffer = context.fromLAObject(la_edge_mean)
		let mtl_edge_variance: MTLBuffer = context.fromLAObject(la_edge_logvariance)
		let mtl_edge_logvariance: MTLBuffer = context.fromLAObject(la_edge_logvariance)
		
		let la_delta_mean: la_object_t = la_matrix_from_float_buffer(uniform(rows), la_count_t(rows), la_count_t(1), la_count_t(1), NOHINT, ATTR)
		let la_delta_variance: la_object_t = la_matrix_from_float_buffer(uniform(rows), la_count_t(rows), la_count_t(1), la_count_t(1), NOHINT, ATTR)
		
		let eps: Float = 0.5
		
		
	}
}

