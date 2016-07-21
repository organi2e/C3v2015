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
	var buffer: [Float] {
		let rows: Int = Int(la_matrix_rows(self))
		let cols: Int = Int(la_matrix_cols(self))
		let buffer: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(buffer), la_count_t(cols), self)
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
