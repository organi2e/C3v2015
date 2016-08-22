//
//  Misc.swift
//  C³
//
//  Created by Kota Nakano on 8/22/16.
//
//

internal struct RingBuffer<T> {
	private var cursor: Int
	private let buffer: [T]
	mutating func progress() {
		cursor = ( cursor + 1 ) % length
	}
	init(let array: [T]) {
		cursor = 0
		buffer = array
	}
	var new: T {
		return buffer[(cursor+length-0)%length]
	}
	var old: T {
		return buffer[(cursor+length-1)%length]
	}
	var length: Int {
		return buffer.count
	}
}