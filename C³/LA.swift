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
infix operator <> { associativity left precedence 120 }
func <> (let lhs: la_object_t, let rhs: la_object_t)->la_object_t {
	return la_matrix_product(lhs, rhs)
}
infix operator -| { associativity left precedence 120 }
func -| (let lhs: la_object_t, let rhs: la_object_t)->la_object_t {
	return la_inner_product(lhs, rhs)
}
infix operator |- { associativity left precedence 120 }
func |- (let lhs: la_object_t, let rhs: la_object_t)->la_object_t {
	return la_outer_product(lhs, rhs)
}