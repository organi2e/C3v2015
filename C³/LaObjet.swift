//
//  Gaussian.swift
//  Mac
//
//  Created by Kota Nakano on 7/20/16.
//
//
import Accelerate

private let ATTR: la_attribute_t = la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)
private let HINT: la_hint_t = la_hint_t(LA_NO_HINT)
private let TYPE: la_scalar_type_t = la_scalar_type_t(LA_SCALAR_TYPE_FLOAT)
private let SUCCESS: la_status_t = la_status_t(LA_SUCCESS)

public typealias LaObjet = la_object_t

internal extension LaObjet {
	var rows: Int {
		return Int(la_matrix_rows(self))
	}
	var cols: Int {
		return Int(la_matrix_cols(self))
	}
	var count: Int {
		return Int(la_matrix_rows(self)*la_matrix_cols(self))
	}
	var status: Int {
		return Int(la_status(self))
	}
	var T: LaObjet {
		return la_transpose(self)
	}
	var length: Int {
		return Int(la_vector_length(self))
	}
	var L1Norm: Float {
		return la_norm_as_float(self, la_norm_t(LA_L1_NORM))
	}
	var L2Norm: Float {
		return la_norm_as_float(self, la_norm_t(LA_L2_NORM))
	}
	var LINFNorm: Float {
		return la_norm_as_float(self, la_norm_t(LA_LINF_NORM))
	}
	var array: [Float] {
		let buffer: [Float] = [Float](count: count, repeatedValue: 0)
		assert(la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), la_matrix_cols(self), self) == SUCCESS)
		return buffer
	}
	var isSplat: Bool {
		return la_matrix_cols(self) == 0 && la_matrix_rows(self) == 0
	}
	subscript(index: Int) -> LaObjet {
		return la_splat_from_vector_element(self, la_index_t(index))
	}
	subscript(row: Int, col: Int) -> LaObjet {
		return la_splat_from_matrix_element(self, la_index_t(row), la_index_t(col))
	}
	func getBytes(buffer: UnsafePointer<Void>) -> Bool {
		return la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), la_count_t(la_matrix_cols(self)), self) == SUCCESS
	}
	func eval(buffer: [Float]) -> Bool {
		return getBytes(buffer)
	}
	func subvec(offset offset: Int, length: Int, stride: Int = 1) -> LaObjet {
		return la_vector_slice(self, la_index_t(offset), la_index_t(stride), la_count_t(length))
	}
	func submat(offset offset: (rows: Int, cols: Int), length: (rows: Int, cols: Int), stride: (rows: Int, cols: Int) = (1, 1)) -> LaObjet {
		return la_matrix_slice(self, la_index_t(offset.rows), la_index_t(offset.cols), la_index_t(stride.rows), la_index_t(stride.cols), la_count_t(length.rows), la_count_t(length.cols))
	}
}

internal prefix func -(lhs: LaObjet) -> LaObjet { return la_scale_with_float(lhs, -1) }

internal func +(lhs: LaObjet, rhs: LaObjet) -> LaObjet { return la_sum(lhs, rhs) }
internal func +(lhs: LaObjet, rhs: Float) -> LaObjet { return la_sum(lhs, la_splat_from_float(rhs, ATTR)) }
internal func +(lhs: Float, rhs: LaObjet) -> LaObjet { return la_sum(la_splat_from_float(lhs, ATTR), rhs) }

internal func -(lhs: LaObjet, rhs: LaObjet) -> LaObjet { return la_difference(lhs, rhs) }
internal func -(lhs: LaObjet, rhs: Float) -> LaObjet { return la_difference(lhs, la_splat_from_float(rhs, ATTR)) }
internal func -(lhs: Float, rhs: LaObjet) -> LaObjet { return la_difference(la_splat_from_float(lhs, ATTR), rhs) }

internal func *(lhs: LaObjet, rhs: LaObjet) -> LaObjet {
	if lhs.count == 0 && rhs.count == 0 {
		var x: Float = 0
		var y: Float = 0
		assert(la_matrix_to_float_buffer(&x, 1, la_matrix_from_splat(lhs, 1, 1))==SUCCESS)
		assert(la_matrix_to_float_buffer(&y, 1, la_matrix_from_splat(rhs, 1, 1))==SUCCESS)
		return la_splat_from_float(x*y, ATTR)
	} else if lhs.count == 1 && rhs.count == 1 {
		return la_elementwise_product(lhs, rhs)
	} else {
		return la_elementwise_product(lhs.count == 1 ? la_splat_from_matrix_element(lhs, 0, 0) : lhs, rhs.count == 1 ? la_splat_from_matrix_element(rhs, 0, 0) : rhs)
	}
}
internal func *(lhs: LaObjet, rhs: Float) -> LaObjet {
	if lhs.count == 0 {
		var value: Float = 0
		assert(la_matrix_to_float_buffer(&value, 1, la_matrix_from_splat(lhs, 1, 1))==SUCCESS)
		return la_splat_from_float(value*rhs, ATTR)
	}
	else {
		return la_scale_with_float(lhs, rhs)
	}
}
internal func *(lhs: Float, rhs: LaObjet) -> LaObjet {
	if rhs.count == 0 {
		var value: Float = 0
		assert(la_matrix_to_float_buffer(&value, 1, la_matrix_from_splat(rhs, 1, 1))==SUCCESS)
		return la_splat_from_float(value*lhs, ATTR)
	} else {
		return la_scale_with_float(rhs, lhs)
	}
}

internal func /(lhs: LaObjet, rhs: LaObjet) -> LaObjet {
	if lhs.count == 0 && rhs.count == 0 { // return splat
		var y: Float = 0
		var x: Float = 1
		assert(la_matrix_to_float_buffer(&y, 1, la_matrix_from_splat(lhs, 1, 1))==SUCCESS)
		assert(la_matrix_to_float_buffer(&x, 1, la_matrix_from_splat(rhs, 1, 1))==SUCCESS)
		return la_splat_from_float(Float(Double(y)/Double(x)), ATTR)
	} else if lhs.count != 0 && rhs.count == 0 {
		var x: Float = 1
		assert(la_matrix_to_float_buffer(&x, 1, la_matrix_from_splat(rhs, 1, 1))==SUCCESS)
		return la_scale_with_float(lhs, Float(1/Double(x)))
	} else if lhs.count != 0 && rhs.count == 1 {
		var x: Float = 1
		assert(la_matrix_to_float_buffer(&x, 1, rhs)==SUCCESS)
		return la_scale_with_float(lhs, Float(1/Double(x)))
	} else {
		let result: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*rhs.count))
		assert(la_matrix_to_float_buffer(result, la_matrix_cols(rhs), rhs)==la_status_t(LA_SUCCESS))
		vvrecf(result, result, [Int32(rhs.count)])
		return la_elementwise_product(lhs.count == 1 ? la_splat_from_matrix_element(lhs, 0, 0) : lhs, la_matrix_from_float_buffer_nocopy(result, la_matrix_rows(rhs), la_matrix_cols(rhs), la_matrix_cols(rhs), HINT, free, ATTR))
	}
}
internal func /(lhs: LaObjet, rhs: Float) -> LaObjet {
	if lhs.count == 0 {
		var value: Float = 0
		assert(la_matrix_to_float_buffer(&value, 1, la_matrix_from_splat(lhs, 1, 1))==SUCCESS)
		return la_splat_from_float(value/rhs, ATTR)
	} else {
		return la_scale_with_float(lhs, 1/rhs)
	}
}
internal func /(lhs: Float, rhs: LaObjet) -> LaObjet {
	if rhs.count == 0 {
		var value: Float = 0
		assert(la_matrix_to_float_buffer(&value, 1, la_matrix_from_splat(rhs, 1, 1))==SUCCESS)
		return la_splat_from_float(lhs/value, ATTR)
	} else {
		let result: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*rhs.count))
		assert(la_matrix_to_float_buffer(result, la_matrix_cols(rhs), rhs)==SUCCESS)
		vvrecf(result, result, [Int32(rhs.count)])
		return la_scale_with_float(la_matrix_from_float_buffer_nocopy(result, la_matrix_rows(rhs), la_matrix_cols(rhs), la_matrix_cols(rhs), HINT, free, ATTR), lhs)
	}
}
internal func L1Normalize(x: LaObjet) -> LaObjet {
	return la_normalized_vector(x, la_norm_t(LA_L1_NORM))
}
internal func L2Normalize(x: LaObjet) -> LaObjet {
	return la_normalized_vector(x, la_norm_t(LA_L2_NORM))
}
internal func LINFNormalize(x: LaObjet) -> LaObjet {
	return la_normalized_vector(x, la_norm_t(LA_LINF_NORM))
}
internal func inner_product(lhs: LaObjet, _ rhs: LaObjet) -> LaObjet {
	return la_inner_product(lhs, rhs)
}
internal func outer_product(lhs: LaObjet, _ rhs: LaObjet) -> LaObjet {
	return la_outer_product(lhs, rhs)
}
internal func matrix_product(lhs: LaObjet, _ rhs: LaObjet) -> LaObjet {
	return la_matrix_product(lhs, rhs)
}
internal func solve(A lhs: LaObjet, b rhs: LaObjet) -> LaObjet {
	return la_solve(lhs, rhs)
}
internal func LaIdentité(count: Int) -> LaObjet {
	return la_identity_matrix(la_count_t(count), TYPE, ATTR)
}
internal func LaDiagonale(vector: LaObjet) -> LaObjet {
	return la_diagonal_matrix_from_vector(vector, 0)
}
internal func LaValuer(scalar: Float) -> LaObjet {
	return la_splat_from_float(scalar, ATTR)
}
internal func LaMatrice(scalar: Float, rows: Int, cols: Int) -> LaObjet {
	return la_matrix_from_splat(la_splat_from_float(scalar, ATTR), la_count_t(rows), la_count_t(cols))
}
internal func LaMatrice(buffer: UnsafePointer<Void>, rows: Int, cols: Int) -> LaObjet {
	return la_matrix_from_float_buffer(UnsafePointer<Float>(buffer), la_count_t(rows), la_count_t(cols), la_count_t(cols), HINT, ATTR)
}
public func LaMatrice(buffer: UnsafePointer<Void>, rows: Int, cols: Int, deallocator: (@convention(c) (UnsafeMutablePointer<Void>) -> Void)?) -> LaObjet {
	return la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(buffer), la_count_t(rows), la_count_t(cols), la_count_t(cols), HINT, deallocator, ATTR)
}
public func LaVecteur(scalar: Float, length: Int) -> LaObjet {
	return la_vector_from_splat(la_splat_from_float(scalar, ATTR), la_count_t(length))
}
/*
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
		let buffer: [Float] = [Float](count: count, repeatedValue: 0)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), cols, self)
		return buffer
	}
	var dup: la_object_t {
		let count: Int = Int(rows*cols)
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*count))
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), cols, self)
		return la_matrix_from_float_buffer_nocopy(buffer, rows, cols, cols, Config.HINT, { free($0) }, Config.ATTR)
	}
	var T: la_object_t {
		return la_transpose(self)
	}
	func toExpand(let dim: UInt) -> la_object_t {
		assert(cols==1)
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*Int(rows*dim)))
		vDSP_vclr(buffer, 1, rows*dim)
		la_matrix_to_float_buffer(buffer, rows, la_transpose(self))
		(1..<dim).forEach {
			memcpy(buffer.advancedBy(Int($0*rows)), buffer, sizeof(Float)*Int(rows))
		}
		return la_transpose(la_matrix_from_float_buffer_nocopy(buffer, dim, rows, rows, Config.HINT, { free($0) }, Config.ATTR))
	}
	func toIdentity(let dim: UInt) -> la_object_t {
		assert(rows==1)
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*Int(dim*dim*cols)))
		vDSP_vclr(buffer, 1, dim*dim*cols)
		la_matrix_to_float_buffer(buffer, dim*cols, self)
		(1..<dim).forEach {
			memcpy(buffer.advancedBy(Int($0*(dim+1)*cols)), buffer, sizeof(Float)*Int(cols))
		}
		return la_matrix_from_float_buffer_nocopy(buffer, dim, dim*cols, dim*cols, Config.HINT, { free($0) }, Config.ATTR)
	}
	func reshape(let rows r: UInt, let cols c: UInt) -> la_object_t {
		assert(rows*cols != 0)
		assert(rows*cols == r*c)
		assert(r*c != 0)
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*Int(r*c)))
		la_matrix_to_float_buffer(buffer, cols, self)
		return la_matrix_from_float_buffer_nocopy(buffer, r, c, c, Config.HINT, { free($0) }, Config.ATTR)
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
		let buffer: [Float] = [Float](count: rhs.count, repeatedValue: 0)
		//let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(rhs.count)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), rhs.cols, rhs)
		la_vector_to_float_buffer(&y, 1, la_vector_from_splat(lhs, 1))
		vDSP_svdiv(&y, buffer, 1, UnsafeMutablePointer<Float>(buffer), 1, vDSP_Length(rhs.count))
		return la_matrix_from_float_buffer(buffer, rhs.rows, rhs.cols, rhs.cols, Config.HINT, Config.ATTR)
		//return la_matrix_from_float_buffer_nocopy(buffer, rhs.rows, rhs.cols, rhs.cols, Config.HINT, { $0.destroy() }, Config.ATTR)
	} else if rhs.count == 0 {
		var x: Float = 0
		la_vector_to_float_buffer(&x, 1, la_vector_from_splat(lhs, 1))
		return la_scale_with_float(lhs, 1/x)
	} else {
		assert(lhs.rows==rhs.rows)
		assert(lhs.cols==rhs.cols)
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*rhs.count))
		//let buffer: [Float] = [Float](count: rhs.count, repeatedValue: 0)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), rhs.cols, rhs)
		vDSP_svdiv([Float(1.0)], buffer, 1, UnsafeMutablePointer<Float>(buffer), 1, vDSP_Length(rhs.count))
		return la_elementwise_product(lhs, la_matrix_from_float_buffer_nocopy(buffer, rhs.rows, rhs.cols, rhs.cols, Config.HINT, { free($0) }, Config.ATTR))
		//return la_elementwise_product(lhs, la_matrix_from_float_buffer(buffer, rhs.rows, rhs.cols, rhs.cols, Config.HINT, Config.ATTR))
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
		//let buffer: [Float] = [Float](count: rhs.count, repeatedValue: 0)
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*rhs.count))
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), rhs.cols, rhs)
		vDSP_svdiv([lhs], buffer, 1, UnsafeMutablePointer<Float>(buffer), 1, vDSP_Length(rhs.count))
		//return la_matrix_from_float_buffer(buffer, rhs.rows, rhs.cols, rhs.cols, Config.HINT, Config.ATTR)
		return la_matrix_from_float_buffer_nocopy(buffer, rhs.rows, rhs.cols, rhs.cols, Config.HINT, { free($0) }, Config.ATTR)
	}
}
func sqrt(let x: la_object_t) -> la_object_t {
	if x.count == 0 {
		var value: Float = 0
		la_vector_to_float_buffer(&value, 1, la_vector_from_splat(x, 1))
		return la_splat_from_float(sqrtf(value), Config.ATTR)
	} else {
		//let buffer: [Float] = [Float](count: x.count, repeatedValue: 0)
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*x.count))
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), x.cols, x)
		vvsqrtf(UnsafeMutablePointer<Float>(buffer), buffer, [Int32(x.count)])
		//return la_matrix_from_float_buffer(buffer, x.rows, x.cols, x.cols, Config.HINT, Config.ATTR)
		return la_matrix_from_float_buffer_nocopy(buffer, x.rows, x.cols, x.cols, Config.HINT, { free($0) }, Config.ATTR)
	}
}
func exp(let x: la_object_t) -> la_object_t {
	if x.count == 0 {
		var value: Float = 0
		la_vector_to_float_buffer(&value, 1, la_vector_from_splat(x, 1))
		return la_splat_from_float(expf(value), la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	} else {
		let count: Int = x.count
		//let buffer: [Float] = [Float](count: x.count, repeatedValue: 0)
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*count))
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), x.cols, x)
		vvexpf(UnsafeMutablePointer<Float>(buffer), buffer, [Int32(count)])
		//return la_matrix_from_float_buffer(buffer, x.rows, x.cols, x.cols, Config.HINT, Config.ATTR)
		return la_matrix_from_float_buffer_nocopy(buffer, x.rows, x.cols, x.cols, Config.HINT, { free($0) }, Config.ATTR)
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
		return la_splat_from_float(Float(0.5*M_2_SQRTPI*M_SQRT1_2)/S*exp(-0.5*(X-U)*(X-U)/S/S), Config.ATTR)
		
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
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*count))
		//let buffer: [Float] = [Float](count: count, repeatedValue: 0)
		
		let level: [Float] = [Float](count: count, repeatedValue: 0)
		let sigma: [Float] = [Float](count: count, repeatedValue: 0)
		
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(level), cols, la_difference(X, U))
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(sigma), cols, S)
		
		vDSP_vdiv(sigma, 1, level, 1, UnsafeMutablePointer<Float>(buffer), 1, vDSP_Length(count))
		
		vDSP_vsq(buffer, 1, UnsafeMutablePointer<Float>(buffer), 1, vDSP_Length(count))
		vDSP_vsmul(buffer, 1, [Float(-0.5)], UnsafeMutablePointer<Float>(buffer), 1, vDSP_Length(count))
		
		vvexpf(UnsafeMutablePointer<Float>(buffer), buffer, [Int32(count)])
		
		vDSP_vdiv(sigma, 1, buffer, 1, UnsafeMutablePointer<Float>(buffer), 1, vDSP_Length(count))
		vDSP_vsmul(buffer, 1, [Float(0.5*M_2_SQRTPI*M_SQRT1_2)], UnsafeMutablePointer<Float>(buffer), 1, vDSP_Length(count))
		
		//return la_matrix_from_float_buffer(buffer, rows, cols, cols, Config.HINT, Config.ATTR)
		return la_matrix_from_float_buffer_nocopy(buffer, rows, cols, cols, Config.HINT, { free($0) }, Config.ATTR)
	}
}
func step(let x: la_object_t) -> la_object_t {
	if x.count == 0 {
		var value: Float = 0
		la_vector_to_float_buffer(&value, 1, la_vector_from_splat(x, 1))
		return la_splat_from_float(0 < value ? 1 : 0, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	} else {
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*x.count))
		//let buffer: [Float] = [Float](count: x.count, repeatedValue: 0)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), x.cols, x)
		vDSP_vthrsc(buffer, 1, [Float(0.0)], [Float(0.5)], UnsafeMutablePointer<Float>(buffer), 1, vDSP_Length(x.count))
		vDSP_vsadd(buffer, 1, [Float(0.5)], UnsafeMutablePointer<Float>(buffer), 1, vDSP_Length(x.count))
		return la_matrix_from_float_buffer_nocopy(buffer, x.rows, x.cols, x.cols, Config.HINT, { free($0) }, Config.ATTR)
		//return la_matrix_from_float_buffer(buffer, x.rows, x.cols, x.cols, Config.HINT, Config.ATTR)
	}
}
func sign(let x: la_object_t) -> la_object_t {
	if x.count == 0 {
		var value: Float = 0
		la_vector_to_float_buffer(&value, 1, la_vector_from_splat(x, 1))
		return la_splat_from_float(0 < value ? 1 : 0 > value ? -1 : 0, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	} else {
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*x.count))
		//let buffer: [Float] = [Float](count: x.count, repeatedValue: 0)
		let cache: [Float] = [Float](count: x.count, repeatedValue: 0)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), x.cols, x)
		vDSP_vthrsc(buffer, 1, [Float(0.0)], [Float( 0.5)], UnsafeMutablePointer<Float>(cache), 1, vDSP_Length(x.count))
		vDSP_vneg(buffer, 1, UnsafeMutablePointer<Float>(buffer), 1, vDSP_Length(x.count))
		vDSP_vthrsc(buffer, 1, [Float(0.0)], [Float(-0.5)], UnsafeMutablePointer<Float>(buffer), 1, vDSP_Length(x.count))
		vDSP_vadd(cache, 1, buffer, 1, UnsafeMutablePointer<Float>(buffer), 1, vDSP_Length(x.count))
		return la_matrix_from_float_buffer_nocopy(buffer, x.rows, x.cols, x.cols, Config.HINT, { free($0) }, Config.ATTR)
		//return la_matrix_from_float_buffer(buffer, x.rows, x.cols, x.cols, Config.HINT, Config.ATTR)
	}
}
func sigmoid(let x: la_object_t) -> la_object_t {
	if x.count == 0 {
		var value: Float = 0
		la_vector_to_float_buffer(&value, 1, la_vector_from_splat(x, 1))
		return la_splat_from_float(0.5+0.5*tanh(0.5*value), Config.ATTR)
	} else {
		var half: Float = 0.5
		//let buffer: [Float] = [Float](count: x.count, repeatedValue: 0)
		let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*x.count))
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), x.cols, x)
		vDSP_vsmul(UnsafePointer<Float>(buffer), 1, &half, UnsafeMutablePointer<Float>(buffer), 1, vDSP_Length(x.count))
		vvtanhf(UnsafeMutablePointer<Float>(buffer), UnsafePointer<Float>(buffer), [Int32(x.count)])
		vDSP_vsmsa(UnsafePointer<Float>(buffer), 1, &half, &half, UnsafeMutablePointer<Float>(buffer), 1, vDSP_Length(x.count))
		//return la_matrix_from_float_buffer(buffer, x.rows, x.cols, x.cols, Config.HINT, Config.ATTR)
		return la_matrix_from_float_buffer_nocopy(buffer, x.rows, x.cols, x.cols, Config.HINT, { free($0) }, Config.ATTR)
	}
}
func normal(let rows rows: UInt, let cols: UInt) -> la_object_t {
	
	let count: Int = Int(rows*cols)
	let buffer: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*count))
//	let buffer: [Float] = [Float](count: count, repeatedValue: 0)

	let N: vDSP_Length = vDSP_Length(count)
	let H: vDSP_Length = vDSP_Length(N/2)
	
	let W: [UInt16] = [UInt16](count: count, repeatedValue: 0)
	let C: [Float] = [Float](count: count, repeatedValue: 0)
	
	let L: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(C).advancedBy(Int(0))
	let R: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(C).advancedBy(Int(H))
	let P: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(buffer).advancedBy(Int(0))
	let Q: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(buffer).advancedBy(Int(H))
	
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

//	return la_matrix_from_float_buffer(buffer, rows, cols, cols, Config.HINT, Config.ATTR)
	return la_matrix_from_float_buffer_nocopy(buffer, rows, cols, cols, Config.HINT, { free($0) }, Config.ATTR)
}
*/
