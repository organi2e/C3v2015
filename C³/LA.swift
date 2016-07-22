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
