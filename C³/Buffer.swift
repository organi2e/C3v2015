//
//  Buffer.swift
//  C³
//
//  Created by Kota Nakano on 6/6/16.
//
//
import CoreData
import Metal
import simd

protocol Buffer {
	var raw: NSData { get }
	var stream: UnsafeMutableBufferPointer<UInt8> { get }
	var scalar: UnsafeMutableBufferPointer<Float> { get }
	var vector: UnsafeMutableBufferPointer<float4> { get }
	var matrix: UnsafeMutableBufferPointer<float4x4> { get }
}

class cpuBuffer: Buffer {
	let raw: NSData
	let stream: UnsafeMutableBufferPointer<UInt8>
	let scalar: UnsafeMutableBufferPointer<Float>
	let vector: UnsafeMutableBufferPointer<float4>
	let matrix: UnsafeMutableBufferPointer<float4x4>
	init ( let buffer: NSData ) {
		raw = buffer
		stream = UnsafeMutableBufferPointer<UInt8>(start: UnsafeMutablePointer<UInt8>(raw.bytes), count: raw.length/sizeof(UInt8))
		scalar = UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(raw.bytes), count: raw.length/sizeof(Float))
		vector = UnsafeMutableBufferPointer<float4>(start: UnsafeMutablePointer<float4>(raw.bytes), count: raw.length/sizeof(float4))
		matrix = UnsafeMutableBufferPointer<float4x4>(start: UnsafeMutablePointer<float4x4>(raw.bytes), count: raw.length/sizeof(float4x4))
	}
}

class mtlBuffer: cpuBuffer {
	let mtl: MTLBuffer
	init ( let buffer: MTLBuffer ) {
		mtl = buffer
		super.init(buffer: NSData(bytesNoCopy: mtl.contents(), length: mtl.length, freeWhenDone: false))
	}
	deinit {
		mtl.setPurgeableState(.Empty)
	}
}