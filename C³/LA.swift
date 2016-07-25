//
//  Gaussian.swift
//  Mac
//
//  Created by Kota Nakano on 7/20/16.
//
//
import Accelerate
extension la_object_t {
	var status: Int32 {
		return Int32(la_status(self))
	}
	var rows: UInt {
		return la_matrix_rows(self)
	}
	var cols: UInt {
		return la_matrix_cols(self)
	}
	var width: UInt {
		return rows*cols
	}
	var count: Int {
		return Int(width)
	}
	var eval: [Float] {
		let count: Int = Int(rows*cols)
		let buffer: [Float] = [Float](count: count, repeatedValue: 0)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), cols, self)
		return buffer
	}
	static var zeros: la_object_t {
		return la_splat_from_float(0, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	}
	static var ones: la_object_t {
		return la_splat_from_float(1, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	}
}
func +(let lhs: la_object_t, let rhs: la_object_t)->la_object_t {
	return la_sum(lhs, rhs)
}
func -(let lhs: la_object_t, let rhs: la_object_t)->la_object_t {
	return la_difference(lhs, rhs)
}
func *(let lhs: la_object_t, let rhs: la_object_t)->la_object_t {
	return la_elementwise_product(lhs, rhs)
}
func /(let lhs: la_object_t, let rhs: la_object_t)->la_object_t {
	if lhs.count == 0 && rhs.count == 0 {
		var y: Float = 0, x: Float = 0
		assert(la_vector_to_float_buffer(&y, 1, la_vector_from_splat(lhs, 1))==0)
		assert(la_vector_to_float_buffer(&x, 1, la_vector_from_splat(rhs, 1))==0)
		return la_splat_from_float(y/x, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	} else if lhs.count == 0 {
		var y: Float = 0
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*rhs.count))
		la_matrix_to_float_buffer(buffer, rhs.cols, rhs)
		la_vector_to_float_buffer(&y, 1, la_vector_from_splat(lhs, 1))
		vDSP_svdiv(&y, buffer, 1, buffer, 1, vDSP_Length(rhs.count))
		return la_matrix_from_float_buffer_nocopy(buffer, rhs.rows, rhs.cols, rhs.cols, la_hint_t(LA_NO_HINT), { free($0) }, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	} else if rhs.count == 0 {
		var x: Float = 0
		la_vector_to_float_buffer(&x, 1, la_vector_from_splat(lhs, 1))
		return la_scale_with_float(lhs, 1/x)
	} else {
		assert(lhs.rows==rhs.rows)
		assert(lhs.cols==rhs.cols)
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*rhs.count))
		la_matrix_to_float_buffer(buffer, rhs.cols, rhs)
		vDSP_svdiv([Float(1.0)], buffer, 1, buffer, 1, vDSP_Length(rhs.count))
		return la_elementwise_product(lhs, la_matrix_from_float_buffer_nocopy(buffer, rhs.rows, rhs.cols, rhs.cols, la_hint_t(LA_NO_HINT), { free($0) }, la_attribute_t(LA_DEFAULT_ATTRIBUTES)))
	}
}

func +(let lhs: la_object_t, let rhs: Float) -> la_object_t {
	return la_sum(lhs, la_splat_from_float(rhs, la_attribute_t(LA_DEFAULT_ATTRIBUTES)))
}
func +(let lhs: Float, let rhs: la_object_t) -> la_object_t {
	return la_sum(la_splat_from_float(lhs, la_attribute_t(LA_DEFAULT_ATTRIBUTES)), rhs)
}

func -(let lhs: la_object_t, let rhs: Float) -> la_object_t {
	return la_sum(lhs, la_splat_from_float(rhs, la_attribute_t(LA_DEFAULT_ATTRIBUTES)))
}
func -(let lhs: Float, let rhs: la_object_t) -> la_object_t {
	return la_difference(la_splat_from_float(lhs, la_attribute_t(LA_DEFAULT_ATTRIBUTES)), rhs)
}

func *(let lhs: la_object_t, let rhs: Float) -> la_object_t {
	return la_scale_with_float(lhs, rhs)
}
func *(let lhs: Float, let rhs: la_object_t) -> la_object_t {
	return la_scale_with_float(rhs, lhs)
}

func /(let lhs: la_object_t, let rhs: Float) -> la_object_t {
	return la_scale_with_float(lhs, 1/rhs)
}
func /(let lhs: Float, let rhs: la_object_t) -> la_object_t {
	if rhs.count == 0 {
		var value: Float = 0
		la_vector_to_float_buffer(&value, 1, la_vector_from_splat(rhs, 1))
		return la_splat_from_float(lhs/value, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	} else {
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*rhs.count))
		la_matrix_to_float_buffer(buffer, rhs.cols, rhs)
		vDSP_svdiv([Float(1.0)], buffer, 1, buffer, 1, vDSP_Length(rhs.count))
		return la_scale_with_float(la_matrix_from_float_buffer_nocopy(buffer, rhs.rows, rhs.cols, rhs.cols, la_hint_t(LA_NO_HINT), { free($0) }, la_attribute_t(LA_DEFAULT_ATTRIBUTES)), lhs)
	}
}
func sqrt(let x: la_object_t) -> la_object_t {
	if x.count == 0 {
		var value: Float = 0
		la_vector_to_float_buffer(&value, 1, la_vector_from_splat(x, 1))
		return la_splat_from_float(sqrtf(value), la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	} else {
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(x.count)
		la_matrix_to_float_buffer(buffer, x.cols, x)
		vvsqrtf(buffer, buffer, [Int32(x.count)])
		return la_matrix_from_float_buffer_nocopy(buffer, x.rows, x.cols, x.cols, la_hint_t(LA_NO_HINT), { $0.destroy() }, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	}
}
func exp(let x: la_object_t) -> la_object_t {
	if x.count == 0 {
		var value: Float = 0
		la_vector_to_float_buffer(&value, 1, la_vector_from_splat(x, 1))
		return la_splat_from_float(expf(value), la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	} else {
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*x.count))
		la_matrix_to_float_buffer(buffer, x.cols, x)
		vvexpf(buffer, buffer, [Int32(x.count)])
		return la_matrix_from_float_buffer_nocopy(buffer, x.rows, x.cols, x.cols, la_hint_t(LA_NO_HINT), { free($0) }, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	}
}
func pdf(let x x: la_object_t, let mu u: la_object_t, let sigma s: la_object_t ) -> la_object_t {
	
	if x.count == 0 && u.count == 0 && s.count == 0 {
		var X: Float = 0
		var U: Float = 0
		var S: Float = 0
		la_vector_to_float_buffer(&X, 1, la_vector_from_splat(x, 1))
		la_vector_to_float_buffer(&U, 1, la_vector_from_splat(s, 1))
		la_vector_to_float_buffer(&S, 1, la_vector_from_splat(u, 1))
		return la_splat_from_float(Float(0.5*M_2_SQRTPI*M_SQRT1_2)/S*exp(-0.5*(X-U)*(X-U)/S/S), la_attribute_t(LA_DEFAULT_ATTRIBUTES))
		
	} else {
		
		let rows: UInt = max(x.rows, u.rows, s.rows)
		let cols: UInt = max(x.cols, u.cols, s.cols)
		
		assert((x.rows==0&&x.cols==0)||(x.rows==rows&&x.cols==cols))
		assert((u.rows==0&&u.cols==0)||(u.rows==rows&&u.cols==cols))
		assert((s.rows==0&&s.cols==0)||(s.rows==rows&&s.cols==cols))
		
		let X: la_object_t = x.count == 0 ? la_matrix_from_splat(x, rows, cols) : x
		let U: la_object_t = u.count == 0 ? la_matrix_from_splat(u, rows, cols) : u
		let S: la_object_t = s.count == 0 ? la_matrix_from_splat(s, rows, cols) : s
		
		let count: Int = Int(rows*cols)
		let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*count))
		
		let level: [Float] = [Float](count: count, repeatedValue: 0)
		let sigma: [Float] = [Float](count: count, repeatedValue: 0)
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(level), cols, la_difference(X, U))
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(sigma), cols, S)
		
		vDSP_vdiv(sigma, 1, level, 1, cache, 1, vDSP_Length(count))
		
		vDSP_vsq(cache, 1, cache, 1, vDSP_Length(count))
		vDSP_vsmul(cache, 1, [Float(-0.5)], cache, 1, vDSP_Length(count))
		
		vvexpf(cache, cache, [Int32(count)])
		
		vDSP_vdiv(sigma, 1, cache, 1, cache, 1, vDSP_Length(count))
		vDSP_vsmul(cache, 1, [Float(0.5*M_2_SQRTPI*M_SQRT1_2)], cache, 1, vDSP_Length(count))
		
		return la_matrix_from_float_buffer_nocopy(cache, rows, cols, cols, la_hint_t(LA_NO_HINT), { free($0) }, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	}
}
func step(let x: la_object_t) -> la_object_t {
	if x.count == 0 {
		var value: Float = 0
		la_vector_to_float_buffer(&value, 1, la_vector_from_splat(x, 1))
		return la_splat_from_float(0 < value ? 1 : 0, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	} else {
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*x.count))
		la_matrix_to_float_buffer(buffer, x.cols, x)
		/*
		(0..<x.count).forEach {
			let ref: UnsafeMutablePointer<Float> = buffer.advancedBy($0)
			ref.memory = 0 < ref.memory ? 1 : 0
		}
		*/
		vDSP_vthrsc(buffer, 1, [Float(0.0)], [Float(0.5)], buffer, 1, vDSP_Length(x.count))
		vDSP_vsadd(buffer, 1, [Float(0.5)], buffer, 1, vDSP_Length(x.count))
		return la_matrix_from_float_buffer_nocopy(buffer, x.rows, x.cols, x.cols, la_hint_t(LA_NO_HINT), { free($0) }, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
		/*
		let buffer: [Float] = [Float](count: x.count, repeatedValue: 0)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), x.cols, x)
		return la_matrix_from_float_buffer(buffer.map{ 0 < $0 ? 1 : 0 }, x.rows, x.cols, x.cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_DEFAULT_ATTRIBUTES))
		*/
	}
}
func sign(let x: la_object_t) -> la_object_t {
	if x.count == 0 {
		var value: Float = 0
		la_vector_to_float_buffer(&value, 1, la_vector_from_splat(x, 1))
		return la_splat_from_float(0 < value ? 1 : 0 > value ? -1 : 0, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	} else {
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*x.count))
		la_matrix_to_float_buffer(buffer, x.cols, x)
		(0..<x.count).forEach {
			let ref: UnsafeMutablePointer<Float> = buffer.advancedBy($0)
			ref.memory = 0 < ref.memory ? 1 : 0 > ref.memory ? -1 : 0
		}
		return la_matrix_from_float_buffer_nocopy(buffer, x.rows, x.cols, x.cols, la_hint_t(LA_NO_HINT), { free($0) }, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
		/*
		let buffer: [Float] = [Float](count: x.count, repeatedValue: 0)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), x.cols, x)
		return la_matrix_from_float_buffer(buffer.map{ 0 < $0 ? 1 : 0 > $0 ? -1 : 0 }, x.rows, x.cols, x.cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_DEFAULT_ATTRIBUTES))
		*/
	}
}
func normal(let rows rows: UInt, let cols: UInt) -> la_object_t {
	
	let count: Int = Int(rows*cols)
	let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*count))
	
	let N: vDSP_Length = vDSP_Length(count)
	let H: vDSP_Length = vDSP_Length(N/2)
	
	let W: [UInt16] = [UInt16](count: count, repeatedValue: 0)
	let C: [Float] = [Float](count: count, repeatedValue: 0)
	
	let L: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(C).advancedBy(Int(0))
	let R: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(C).advancedBy(Int(H))
	let P: UnsafeMutablePointer<Float> = cache.advancedBy(Int(0))
	let Q: UnsafeMutablePointer<Float> = cache.advancedBy(Int(H))
	
	arc4random_buf(UnsafeMutablePointer<Void>(W), sizeof(UInt16)*W.count)
	vDSP_vfltu16(UnsafePointer<UInt16>(W), 1, UnsafeMutablePointer<Float>(C), 1, vDSP_Length(count))
	
	vDSP_vsadd(L, 1, [Float(1.0)], L, 1, H)
	vDSP_vsdiv(L, 1, [Float(UInt16.max)+1.0], L, 1, N)
	
	vvlogf(L, L, [Int32(H)])
	vDSP_vsmul(L, 1, [Float(-2.0)], L, 1, H)
	vvsqrtf(L, L, [Int32(H)])
	
	vDSP_vsmul(R, 1, [Float(2.0*M_PI)], R, 1, H)
	vvsincosf(P, Q, R, [Int32(H)])
	
	vDSP_vmul(P, 1, L, 1, P, 1, H)
	vDSP_vmul(Q, 1, L, 1, Q, 1, H)

	return la_matrix_from_float_buffer_nocopy(cache, rows, cols, cols, la_hint_t(LA_NO_HINT), { free($0) }, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
}