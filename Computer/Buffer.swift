//
//  Buffer.swift
//  C³
//
//  Created by Kota Nakano on 6/6/16.
//
//
import simd

protocol Buffer {
	var raw: NSData { get }
	var stream: UnsafeMutableBufferPointer<UInt8> { get }
	var scalar: UnsafeMutableBufferPointer<Float> { get }
	var vector: UnsafeMutableBufferPointer<float4> { get }
	var matrix: UnsafeMutableBufferPointer<float4x4> { get }
}
