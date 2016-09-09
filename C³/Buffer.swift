//
//  Buffer.swift
//  C³
//
//  Created by Kota Nakano on 9/8/16.
//
//
import Accelerate
import Metal
import simd
public typealias Buffer = MTLBuffer

internal extension Buffer {
	var bytes: UnsafeMutablePointer<Float> {
		return UnsafeMutablePointer<Float>(contents())
	}
	var vecteur: LaObjet {
		return LaMatrice(contents(), rows: length/sizeof(Float), cols: 1, deallocator: nil)
	}
}

func step(y y: Buffer, x: Buffer) {
	let count: Int = min(y.length, x.length) / sizeof(Float)
	/* simd */
	let yref: UnsafeMutablePointer<float4> = UnsafeMutablePointer<float4>(y.bytes)
	let xref: UnsafePointer<float4> = UnsafePointer<float4>(x.bytes)
	(0..<(count+3)/4).forEach { yref[$0] = step(xref[$0], edge: float4(0)) }
	/* Accelerate */
	/*
	let length: vDSP_Length = vDSP_Length(count)
	let yref: UnsafeMutablePointer<Float> = y.bytes
	let xref: UnsafeMutablePointer<Float> = x.bytes
	
	var zero: Float = 0.0
	var half: Float = 0.5
	
	vDSP_vneg(xref, 1, yref, 1, length)
	vDSP_vlim(yref, 1, &zero, &half, yref, 1, length)
	vDSP_vneg(yref, 1, yref, 1, length)
	vDSP_vsadd(yref, 1, &half, yref, 1, length)
	*/
}
func sign(y y: Buffer, x: Buffer) {
	
	let count: Int = min(y.length, x.length) / sizeof(Float)
	
	assert(y.length==sizeof(Float)*count)
	assert(x.length==sizeof(Float)*count)
	
	/* simd */
	let yref: UnsafeMutablePointer<float4> = UnsafeMutablePointer<float4>(y.bytes)
	let xref: UnsafePointer<float4> = UnsafePointer<float4>(x.bytes)
	(0..<(count+3)/4).forEach { yref[$0] = sign(xref[$0]) }
	/* Accelerate */
	/*
	let length: vDSP_Length = vDSP_Length(count)
	let yref: UnsafeMutablePointer<Float> = y.bytes
	let xref: UnsafeMutablePointer<Float> = x.bytes
	
	var len: Int32 = Int32(count)
	
	var one: Float = 1.0
	var zero: Float = 0
	var posi: Float = 0.5
	var nega: Float = -0.5
	
	vDSP_vneg(δ, 1, Δ.σ, 1, length)
	vDSP_vlim(δ, 1, &zero, &posi, Δ.μ, 1, length)
	vDSP_vlim(Δ.σ, 1, &zero, &nega, Δ.σ, 1, length)
	vDSP_vadd(Δ.μ, 1, Δ.σ, 1, Δ.χ, 1, length)
	*/
}