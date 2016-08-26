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

func μGrad(value: Float) -> Float {
	return 1.0
}
func σGrad(value: Float) -> Float {
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
		
		let o_width: Int = 16//4 * Int(1+arc4random_uniform(255))
		let i_width: Int = 16//4 * Int(1+arc4random_uniform(255))
		
		let state_la: la_object_t = la_matrix_from_float_buffer(uniform(i_width), la_count_t(i_width), la_count_t(1), la_count_t(1), NOHINT, ATTR)
		let state_mtl: MTLBuffer = context.fromLAObject(state_la)
		
		let edge_la = (
			χ: la_matrix_from_float_buffer(uniform(o_width*i_width), la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR),
			μ: la_matrix_from_float_buffer(uniform(o_width*i_width), la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR),
			σ: la_matrix_from_float_buffer(uniform(o_width*i_width), la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR)
		)
		
		let edge_mtl = (
			χ: context.fromLAObject(edge_la.χ),
			μ: context.fromLAObject(edge_la.μ),
			σ: context.fromLAObject(edge_la.σ)
		)
		
		let level_mtl = (
			χ: context.newBuffer(length: sizeof(Float)*o_width),
			μ: context.newBuffer(length: sizeof(Float)*o_width),
			σ: context.newBuffer(length: sizeof(Float)*o_width)
		)
		
		measureBlock {
			Edge.collect(context: self.context, level: level_mtl, edge: edge_mtl, input: state_mtl, rows: o_width, cols: i_width)
			self.context.join()
		}
		
		context.newBlitCommand {
			$0.fillBuffer(level_mtl.χ, range: NSRange(location: 0, length: level_mtl.χ.length), value: 0)
			$0.fillBuffer(level_mtl.μ, range: NSRange(location: 0, length: level_mtl.μ.length), value: 0)
			$0.fillBuffer(level_mtl.σ, range: NSRange(location: 0, length: level_mtl.σ.length), value: 0)
		}
		
		Edge.collect(context: self.context, level: level_mtl, edge: edge_mtl, input: state_mtl, rows: o_width, cols: i_width)
		
		let level_mtl_la = (
			χ: context.toLAObject(level_mtl.χ, rows: o_width, cols: 1),
			μ: context.toLAObject(level_mtl.μ, rows: o_width, cols: 1),
			σ: context.toLAObject(level_mtl.σ, rows: o_width, cols: 1)
		)
		
		let level_la = (
			χ: la_matrix_product(edge_la.χ, state_la),
			μ: la_matrix_product(edge_la.μ, state_la),
			σ: la_matrix_product(edge_la.σ, state_la)
		)
		
		context.join()
		
		let χrmse: Float = la_norm_as_float(la_difference(level_mtl_la.χ, level_la.χ), la_norm_t(LA_L2_NORM)) / sqrt(Float(o_width))
		if 1e-4 < χrmse {
			XCTFail("RMSE: \(χrmse)")
		}
		
		let μrmse: Float = la_norm_as_float(la_difference(level_mtl_la.μ, level_la.μ), la_norm_t(LA_L2_NORM)) / sqrt(Float(o_width))
		if 1e-4 < μrmse {
			XCTFail("RMSE: \(μrmse)")
		}
		
		let σrmse: Float = la_norm_as_float(la_difference(level_mtl_la.σ, level_la.σ), la_norm_t(LA_L2_NORM)) / sqrt(Float(o_width))
		if 1e-4 < σrmse {
			XCTFail("RMSE: \(σrmse)")
		}
		
	}
	func testGradient() {
		
		let o_width: Int = 4 * Int(1+arc4random_uniform(15))
		let i_width: Int = 4 * Int(1+arc4random_uniform(15))

		let srcχ: [Float] = (0..<i_width).map{(_)in Float(arc4random())}
		var srcμ: [Float] = [Float](count: o_width*o_width*i_width, repeatedValue: 0)
		var srcσ: [Float] = [Float](count: o_width*o_width*i_width, repeatedValue: 0)
		
		let input: MTLBuffer = context.newBuffer(srcχ)
		let edgeμ: MTLBuffer = context.newBuffer(srcμ)
		let edgeσ: MTLBuffer = context.newBuffer(srcσ)
		
		measureBlock {
			Edge.gradientInitialize(context: self.context, grad: (edgeμ, edgeσ), input: input, rows: o_width, cols: i_width)
			self.context.join()
		}
		let dstμ: [Float] = context.toRowMajorMatrix(edgeμ, rows: o_width, cols: i_width*o_width)
		let dstσ: [Float] = context.toRowMajorMatrix(edgeσ, rows: o_width, cols: i_width*o_width)
		
		for k in 0..<o_width {
			for j in 0..<i_width {
				for i in 0..<o_width {
					srcμ[((k*o_width)+i)*i_width+j] = i == k ? srcχ[j] : 0
					srcσ[((k*o_width)+i)*i_width+j] = i == k ? srcχ[j] : 0
				}
			}
		}

		context.join()
		
		let rmseμ: Float = la_norm_as_float(la_difference(la_matrix_from_float_buffer(srcμ, la_count_t(o_width*o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR), la_matrix_from_float_buffer(dstμ, la_count_t(o_width*o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR)), la_norm_t(LA_L2_NORM))
		let rmseσ: Float = la_norm_as_float(la_difference(la_matrix_from_float_buffer(srcσ, la_count_t(o_width*o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR), la_matrix_from_float_buffer(dstσ, la_count_t(o_width*o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR)), la_norm_t(LA_L2_NORM))
		
		XCTAssert(rmseμ<1e-7)
		XCTAssert(rmseσ<1e-7)
		
		XCTAssert(srcμ.elementsEqual(dstμ))
		XCTAssert(srcσ.elementsEqual(dstσ))
		
	}
	
	func testCorrect() {
		
		let o_width: Int = 16
		let i_width: Int = 16
		
		let η: Float = 0.5
		
		let state: [Float] = uniform(i_width)
		
		var logμ: [Float] = [Float](count: o_width*i_width, repeatedValue: 0)
		var logσ: [Float] = [Float](count: o_width*i_width, repeatedValue: 0)
		
		let μ: [Float] = [Float](count: o_width*i_width, repeatedValue: 0)
		let σ: [Float] = [Float](count: o_width*i_width, repeatedValue: 0)
		
		let gradμ: [Float] = [Float](count: o_width*o_width*i_width, repeatedValue: 0)
		let gradσ: [Float] = [Float](count: o_width*o_width*i_width, repeatedValue: 0)
		
		let deltaμ: [Float] = uniform(o_width)
		let deltaσ: [Float] = uniform(o_width)
		
		let input: MTLBuffer = context.fromRowMajorMatrix(state, rows: i_width, cols: 1)
		
		let edge = (
			logμ: context.fromRowMajorMatrix(logμ, rows: o_width, cols: i_width),
			logσ: context.fromRowMajorMatrix(logσ, rows: o_width, cols: i_width),
			μ: context.fromRowMajorMatrix(μ, rows: o_width, cols: i_width),
			σ: context.fromRowMajorMatrix(σ, rows: o_width, cols: i_width)
		)
		let grad = (
			μ: context.fromRowMajorMatrix(gradμ, rows: o_width, cols: o_width*i_width),
			σ: context.fromRowMajorMatrix(gradσ, rows: o_width, cols: o_width*i_width)
		)
		let delta = (
			μ: context.fromRowMajorMatrix(deltaμ, rows: o_width, cols: 1),
			σ: context.fromRowMajorMatrix(deltaσ, rows: o_width, cols: 1)
		)
		
		Edge.gradientInitialize(context: context, grad: grad, input: input, rows: o_width, cols: i_width)
		Edge.correct(context: context, η: η, edge: edge, grad: grad, delta: delta, rows: o_width, cols: i_width)
		
		for i in 0..<o_width {
			for o in 0..<i_width {
				logμ[ o * i_width + i ] += η * μGrad ( μ[o*i_width+i] ) * ( state[i] ) * deltaμ[o]
				logσ[ o * i_width + i ] += η * σGrad ( σ[o*i_width+i] ) * ( state[i] ) * deltaσ[o]
			}
		}
		
		let srcμ: la_object_t = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(logμ), la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, nil, ATTR)
		let dstμ: la_object_t = context.toLAObject(edge.logμ, rows: o_width, cols: i_width)

		let srcσ: la_object_t = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(logσ), la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, nil, ATTR)
		let dstσ: la_object_t = context.toLAObject(edge.logσ, rows: o_width, cols: i_width)
		
		context.join()
		
		let rmseμ: Float = la_norm_as_float(la_difference(srcμ, dstμ), la_norm_t(LA_L2_NORM)) / sqrt(Float(o_width*i_width))
		XCTAssert(!isnan(rmseμ))
		XCTAssert(!isinf(rmseμ))
		if 1e-3 < rmseμ {
			XCTFail("RMSE: \(rmseμ)")
		}
		
		
		let rmseσ: Float = la_norm_as_float(la_difference(srcσ, dstσ), la_norm_t(LA_L2_NORM)) / sqrt(Float(o_width*i_width))
		XCTAssert(!isnan(rmseσ))
		XCTAssert(!isinf(rmseσ))
		if 1e-3 < rmseσ {
			XCTFail("RMSE: \(rmseσ)")
		}
		
	}

	func testCorrectLightWeight() {
		
		let o_width: Int = 4 * Int(1+arc4random_uniform(255))
		let i_width: Int = 4 * Int(1+arc4random_uniform(255))
		
		let χ: [Float] = uniform(o_width*i_width)
		
		var logμ: [Float] = uniform(o_width*i_width)
		var logσ: [Float] = uniform(o_width*i_width)
		
		let μ: [Float] = logμ.map{tanh($0)}
		let σ: [Float] = logσ.map{log(1+exp($0))}
		
		let edge = (
			χ: χ,
			logμ: logμ,
			logσ: logσ,
			μ: μ,
			σ: σ
		)
		
		var error: [Float] = uniform(i_width)
		let state: [Float] = uniform(i_width)

		let error_la: la_object_t = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(error), la_count_t(i_width), 1, 1, NOHINT, nil, ATTR)
		let state_la: la_object_t = la_matrix_from_float_buffer(state, la_count_t(i_width), 1, 1, NOHINT, ATTR)
		
		let error_mtl: MTLBuffer = context.fromLAObject(error_la)
		let state_mtl: MTLBuffer = context.fromLAObject(state_la)
		
		let delta = (
			χ: uniform(o_width),
			μ: uniform(o_width),
			σ: uniform(o_width)
		)
		let delta_la = (
			χ: la_matrix_from_float_buffer(delta.χ, la_count_t(o_width), 1, 1, NOHINT, ATTR),
			μ: la_matrix_from_float_buffer(delta.μ, la_count_t(o_width), 1, 1, NOHINT, ATTR),
			σ: la_matrix_from_float_buffer(delta.σ, la_count_t(o_width), 1, 1, NOHINT, ATTR)
		)
		let delta_mtl = (
			χ: context.fromLAObject(delta_la.χ),
			μ: context.fromLAObject(delta_la.μ),
			σ: context.fromLAObject(delta_la.σ)
		)
		
		let edge_la = (
			logμ: la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(edge.logμ), la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, nil, ATTR),
			logσ: la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(edge.logσ), la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, nil, ATTR),
			χ: la_matrix_from_float_buffer(edge.χ, la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR),
			μ: la_matrix_from_float_buffer(edge.μ, la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR),
			σ: la_matrix_from_float_buffer(edge.σ, la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR)
		)
		
		let edge_mtl = (
			logμ: context.fromLAObject(edge_la.logμ),
			logσ: context.fromLAObject(edge_la.logσ),
			χ: context.fromLAObject(edge_la.χ),
			μ: context.fromLAObject(edge_la.μ),
			σ: context.fromLAObject(edge_la.σ)
		)
		
		let η: Float = 0.5
		
		Edge.backpropagation(context: context, error: error_mtl, edge: edge_mtl.χ, delta: delta_mtl.χ, rows: o_width, cols: i_width)
		Edge.correctLightWeight(context: context, η: η, edge: (edge_mtl.logμ, edge_mtl.logσ, edge_mtl.μ, edge_mtl.σ), input: state_mtl, delta: (delta_mtl.μ, delta_mtl.σ), rows: o_width, cols: i_width)
		
		let obsError_la: la_object_t = context.toLAObject(error_mtl, rows: i_width, cols: 1)
		
		let obsLogμ_la: la_object_t = context.toLAObject(edge_mtl.logμ, rows: o_width, cols: i_width)
		let obsLogσ_la: la_object_t = context.toLAObject(edge_mtl.logσ, rows: o_width, cols: i_width)
		
		for i in 0..<i_width {
			var accum: Float = 0.0
			for o in 0..<o_width {
				
				accum += delta.χ[o] * edge.χ[o * i_width + i]
				//accum += delta.μ[o] * edge.μ[o * i_width + i]
				//accum += delta.σ[o] * edge.σ[o * i_width + i]
				
				logμ[ o * i_width + i ] += η * μGrad ( μ[o*i_width+i] ) * ( state[i] ) * delta.μ[o]
				logσ[ o * i_width + i ] += η * σGrad ( σ[o*i_width+i] ) * ( state[i] ) * delta.σ[o]
				
			}
			error[i] += accum
		}
		
		let dstLogμ_la: la_object_t = la_matrix_from_float_buffer(UnsafePointer<Float>(logμ), la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR)
		let dstLogσ_la: la_object_t = la_matrix_from_float_buffer(UnsafePointer<Float>(logσ), la_count_t(o_width), la_count_t(i_width), la_count_t(i_width), NOHINT, ATTR)
		
		context.join()
		
		let χrmse: Float = la_norm_as_float(la_difference(error_la, obsError_la), la_norm_t(LA_L2_NORM)) / sqrt(Float(i_width))
		XCTAssert(!isnan(χrmse))
		XCTAssert(!isinf(χrmse))
		if 1e-3 < χrmse {
			print("a")
			dump(error_la)
			print("b")
			dump(obsError_la)
			XCTFail("RMSE: \(χrmse)")
		}
		
		let μrmse: Float = la_norm_as_float(la_difference(dstLogμ_la, obsLogμ_la), la_norm_t(LA_L2_NORM)) / sqrt(Float(o_width*i_width))
		XCTAssert(!isnan(μrmse))
		XCTAssert(!isinf(μrmse))
		if 1e-3 < μrmse {
			print("logmu a")
			dump(dstLogμ_la)
			print("logmu b")
			dump(obsLogμ_la)
			XCTFail("RMSE: \(μrmse)")
		}
		
		let σrmse: Float = la_norm_as_float(la_difference(dstLogσ_la, obsLogσ_la), la_norm_t(LA_L2_NORM)) / sqrt(Float(o_width*i_width))
		XCTAssert(!isnan(σrmse))
		XCTAssert(!isinf(σrmse))
		
		if 1e-3 < σrmse {
			print("logsigma a")
			dump(dstLogσ_la)
			print("logsigma b")
			dump(obsLogσ_la)
			XCTFail("RMSE: \(σrmse)")
		}
		
	}
}

