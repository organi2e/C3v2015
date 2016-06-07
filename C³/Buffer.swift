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

internal struct Buffer {
	let mtl: MTLBuffer?
	let raw: NSData
	let stream: UnsafeMutableBufferPointer<UInt8>
	let scalar: UnsafeMutableBufferPointer<Float>
	let vector: UnsafeMutableBufferPointer<float4>
	let matrix: UnsafeMutableBufferPointer<float4x4>
	init( let mtl ref: MTLBuffer? = nil ) {
		if let ref: MTLBuffer = ref {
			mtl = ref
			raw = NSData(bytesNoCopy: ref.contents(), length: ref.length, freeWhenDone: false)
		} else {
			mtl = nil
			raw = NSData()
		}
		stream = UnsafeMutableBufferPointer<UInt8>(start: UnsafeMutablePointer<UInt8>(raw.bytes), count: raw.length)
		scalar = UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(raw.bytes), count: raw.length/sizeof(Float))
		vector = UnsafeMutableBufferPointer<float4>(start: UnsafeMutablePointer<float4>(raw.bytes), count: raw.length/sizeof(Float)/4)
		matrix = UnsafeMutableBufferPointer<float4x4>(start: UnsafeMutablePointer<float4x4>(raw.bytes), count: raw.length/sizeof(Float)/16)
	}
	init( let raw ref: NSData ) {
		mtl = nil
		raw = NSData(data: ref)
		stream = UnsafeMutableBufferPointer<UInt8>(start: UnsafeMutablePointer<UInt8>(raw.bytes), count: raw.length)
		scalar = UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(raw.bytes), count: raw.length/sizeof(Float))
		vector = UnsafeMutableBufferPointer<float4>(start: UnsafeMutablePointer<float4>(raw.bytes), count: raw.length/sizeof(Float)/4)
		matrix = UnsafeMutableBufferPointer<float4x4>(start: UnsafeMutablePointer<float4x4>(raw.bytes), count: raw.length/sizeof(Float)/16)
	}
}