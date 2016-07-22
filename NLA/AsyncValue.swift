//
//  zy_object_t.swift
//  C³
//
//  Created by Kota Nakano on 7/20/16.
//
//
import Accelerate
/*
public struct AsyncValue {
	private var waits: [dispatch_group_t]
	private var value: la_object_t
	public init(let value: la_object_t = la_splat_from_float(0, la_attribute_t(LA_DEFAULT_ATTRIBUTES)), let waits: [dispatch_group_t] = [] ) {
		self.value = value
		self.waits = waits
	}
	public init(let buffer: [Float], let rows: Int, let cols: Int) {
		assert(buffer.count==rows*cols)
		waits = []
		value = la_splat_from_float(0, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	}
	public var buffer: [Float] {
		get {
			let rows: Int = value.rows
			let cols: Int = value.cols
			let count: Int = rows*cols
			let result: [Float] = [Float](count: count, repeatedValue: 0)
			ready()
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(result), la_count_t(cols), value)
			return result
		}
		set {
			let rows: Int = value.rows
			let cols: Int = value.cols
			let count: Int = rows*cols
			assert(newValue.count==count)
			value = la_matrix_from_float_buffer(newValue, la_count_t(rows), la_count_t(cols), la_count_t(cols), la_hint_t(LA_NO_HINT), la_attribute_t(LA_DEFAULT_ATTRIBUTES))
			waits.removeAll()
		}
	}
	public var rows: UInt {
		return la_matrix_rows(value)
	}
	public var cols: UInt {
		return la_matrix_cols(value)
	}
	public func ready() {
		depend.forEach { $0.wait() }
	}
	public var depend: [dispatch_group_t] {
		return waits
	}
}
public func +(let l: AsyncValue, let r: AsyncValue)->AsyncValue {
	return AsyncValue(value: la_sum(l.value, r.value), waits: l.depend + r.depend)
}
public func -(let l: AsyncValue, let r: AsyncValue)->AsyncValue {
	return AsyncValue(value: la_difference(l.value, r.value), waits: l.depend + r.depend)
}
public func *(let l: AsyncValue, let r: AsyncValue)->AsyncValue {
	return AsyncValue(value: la_elementwise_product(l.value, r.value), waits: l.depend + r.depend)
}

public func +(let l: AsyncValue, let r: la_object_t)->AsyncValue {
	return AsyncValue(value: la_sum(l.value, r), waits: l.depend)
}
public func -(let l: AsyncValue, let r: la_object_t)->AsyncValue {
	return AsyncValue(value: la_difference(l.value, r), waits: l.depend)
}
public func *(let l: AsyncValue, let r: la_object_t)->AsyncValue {
	return AsyncValue(value: la_elementwise_product(l.value, r), waits: l.depend)
}

public func +(let l: la_object_t, let r: AsyncValue)->AsyncValue {
	return AsyncValue(value: la_sum(l, r.value), waits: r.depend)
}
public func -(let l: la_object_t, let r: AsyncValue)->AsyncValue {
	return AsyncValue(value: la_difference(l, r.value), waits: r.depend)
}
public func *(let l: la_object_t, let r: AsyncValue)->AsyncValue {
	return AsyncValue(value: la_elementwise_product(l, r.value), waits: r.depend)
}

public func +(let l: la_object_t, let r: la_object_t)->AsyncValue {
	return AsyncValue(value: la_sum(l, r))
}
public func -(let l: la_object_t, let r: la_object_t)->AsyncValue {
	return AsyncValue(value: la_difference(l, r))
}
public func *(let l: la_object_t, let r: la_object_t)->AsyncValue {
	return AsyncValue(value: la_elementwise_product(l, r))
}

public func +(let l: AsyncValue, let r: Float)->AsyncValue {
	return AsyncValue(value: la_sum(l.value, la_splat_from_float(r, la_attribute_t(LA_DEFAULT_ATTRIBUTES))), waits: l.depend)
}
public func -(let l: AsyncValue, let r: Float)->AsyncValue {
	return AsyncValue(value: la_difference(l.value, la_splat_from_float(r, la_attribute_t(LA_DEFAULT_ATTRIBUTES))), waits: l.depend)
}
public func *(let l: AsyncValue, let r: Float)->AsyncValue {
	return AsyncValue(value: la_scale_with_float(l.value, r), waits: l.depend)
}

public func +(let l: Float, let r: AsyncValue)->AsyncValue {
	return AsyncValue(value: la_sum(r.value, la_splat_from_float(l, la_attribute_t(LA_DEFAULT_ATTRIBUTES))), waits: r.depend)
}
public func -(let l: Float, let r: AsyncValue)->AsyncValue {
	return AsyncValue(value: la_difference(r.value, la_splat_from_float(l, la_attribute_t(LA_DEFAULT_ATTRIBUTES))), waits: r.depend)
}
public func *(let l: Float, let r: AsyncValue)->AsyncValue {
	return AsyncValue(value: la_scale_with_float(r.value, l), waits: r.depend)
}
*/