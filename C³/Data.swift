//
//  Data.swift
//  C³
//
//  Created by Kota Nakano on 9/8/16.
//
//
import Foundation
import Compression

internal typealias Data = NSData

private let ALGORITHM: compression_algorithm = COMPRESSION_LZFSE

extension Data {
	var encode: Data {
		let dst_size: Int = compression_encode_buffer(nil, 0, UnsafePointer<UInt8>(bytes), length, nil, ALGORITHM)
		let dst_buff: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.alloc(dst_size)
		assert(dst_size==compression_encode_buffer(dst_buff, dst_size, UnsafePointer<UInt8>(bytes), length, nil, ALGORITHM))
		return NSData(bytesNoCopy: dst_buff, length: dst_size, deallocator: { $0.0.dealloc($0.1) })
	}
	var decode: Data {
		let dst_size: Int = compression_decode_buffer(nil, 0, UnsafePointer<UInt8>(bytes), length, nil, ALGORITHM)
		let dst_buff: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.alloc(dst_size)
		assert(dst_size==compression_decode_buffer(dst_buff, dst_size, UnsafePointer<UInt8>(bytes), length, nil, ALGORITHM))
		return NSData(bytesNoCopy: dst_buff, length: dst_size, deallocator: { $0.0.dealloc($0.1) })
	}
}