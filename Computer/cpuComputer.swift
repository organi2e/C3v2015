//
//  cpuComputer.swift
//  C³
//
//  Created by Kota Nakano on 7/18/16.
//
//

import Foundation
import Accelerate
import simd

public class cpuComputer: Computer {
	
	static let dispatch: (queue: dispatch_queue_t, group: dispatch_group_t, semaphore: dispatch_semaphore_t) = (
		queue: dispatch_queue_create("\(Config.identifier).\(NSStringFromClass(cpuComputer.self)).parallel", DISPATCH_QUEUE_CONCURRENT),
		group: dispatch_group_create(),
		semaphore: dispatch_semaphore_create(1)
	)
	
	let dispatch: (queue: dispatch_queue_t, group: dispatch_group_t, semaphore: dispatch_semaphore_t) = (
		queue: dispatch_queue_create("\(Config.identifier).\(NSStringFromClass(cpuComputer.self)).serial", DISPATCH_QUEUE_SERIAL),
		group: dispatch_group_create(),
		semaphore: dispatch_semaphore_create(1)
	)
	
	func add ( let y: Buffer, let _ a: Buffer, let _ b: Buffer ) {
		assert(y.scalar.count==a.scalar.count)
		assert(y.scalar.count==b.scalar.count)
		vDSP_vadd(a.scalar.baseAddress, 1, b.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
	}
	func sub ( let y: Buffer, let _ a: Buffer, let _ b: Buffer ) {
		assert(y.scalar.count==a.scalar.count)
		assert(y.scalar.count==b.scalar.count)
		vDSP_vadd(b.scalar.baseAddress, 1, a.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
	}
	func mul ( let y: Buffer, let _ a: Buffer, let _ b: Buffer ) {
		assert(y.scalar.count==a.scalar.count)
		assert(y.scalar.count==b.scalar.count)
		vDSP_vadd(a.scalar.baseAddress, 1, b.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
	}
	func div ( let y: Buffer, let _ a: Buffer, let _ b: Buffer ) {
		assert(y.scalar.count==a.scalar.count)
		assert(y.scalar.count==b.scalar.count)
		vDSP_vdiv(b.scalar.baseAddress, 1, a.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
	}
	func add ( let y: Buffer, let _ a: Buffer, let _ b: Float ) {
		assert(y.scalar.count==a.scalar.count)
		vDSP_vsadd(a.scalar.baseAddress, 1, [ b], y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
	}
	func sub ( let y: Buffer, let _ a: Buffer, let _ b: Float ) {
		assert(y.scalar.count==a.scalar.count)
		vDSP_vsadd(a.scalar.baseAddress, 1, [-b], y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
	}
	func mul ( let y: Buffer, let _ a: Buffer, let _ b: Float ) {
		assert(y.scalar.count==a.scalar.count)
		vDSP_vsmul(a.scalar.baseAddress, 1, [ b], y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
	}
	func div ( let y: Buffer, let _ a: Buffer, let _ b: Float ) {
		assert(y.scalar.count==a.scalar.count)
		vDSP_vsdiv(a.scalar.baseAddress, 1, [ b], y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
	}
	
	func abs ( let y: Buffer, let _ x: Buffer ) {
		assert(y.scalar.count==x.scalar.count)
		vDSP_vabs(x.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
	}
	func neg ( let y: Buffer, let _ x: Buffer ) {
		assert(y.scalar.count==x.scalar.count)
		vDSP_vneg(x.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
	}
	func sq ( let y: Buffer, let _ x: Buffer ) {
		assert(y.scalar.count==x.scalar.count)
		vDSP_vsq(x.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
	}
	func sqrt ( let y: Buffer, let _ x: Buffer ) {
		assert(y.scalar.count==x.scalar.count)
		vvsqrtf(y.scalar.baseAddress, x.scalar.baseAddress, [Int32(x.scalar.count)])
	}
	
	func exp ( let y: Buffer, let _ x: Buffer ) {
		assert(y.scalar.count==x.scalar.count)
		vvexpf(y.scalar.baseAddress, x.scalar.baseAddress, [Int32(y.scalar.count)])
	}
	func log ( let y: Buffer, let _ x: Buffer ) {
		assert(y.scalar.count==x.scalar.count)
		vvlogf(y.scalar.baseAddress, x.scalar.baseAddress, [Int32(y.scalar.count)])
	}
	
	func fill( let y: Buffer, let _ a: Float) {
		vDSP_vfill([a], y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
	}
	
	func clamp( let y: Buffer, let _ x: Buffer, let _ a: Float, let _ b: Float) {
		assert(y.scalar.count==x.scalar.count)
		vDSP_vclip(x.scalar.baseAddress, 1, [a], [b], y.scalar.baseAddress, 1, vDSP_Length(x.scalar.count))
	}
	
	func sum ( let x: Buffer ) -> Float {
		var result: Float = 0
		vDSP_sve(x.scalar.baseAddress, 1, &result, vDSP_Length(x.scalar.count))
		return result
	}
	func dot ( let a: Buffer, let _ b: Buffer ) -> Float {
		var result: Float = 0
		assert(a.scalar.count==b.scalar.count)
		vDSP_dotpr(a.scalar.baseAddress, 1, b.scalar.baseAddress, 1, &result, vDSP_Length(a.scalar.count))
		return result
	}
	
	func gemv ( let y y: Buffer, let beta: Float, let a: Buffer, let x: Buffer, let alpha: Float, let n: Int, let m: Int, let trans: Bool ) {
		dispatch_apply(m/4, cpuComputer.dispatch.queue) { ( let r: Int ) in
			var accum: float4 = float4(0)
			if trans {
				(0..<n/4).forEach { ( let c: Int ) in
					accum += a.matrix [ r * n/4 + c ].transpose * x.vector[ c ]
				}
			} else {
				(0..<n/4).forEach { ( let c: Int ) in
					accum += a.matrix [ c * m/4 + r ] * x.vector[ c ]
				}
			}
			y.vector [ r ] = alpha * accum + beta * y.vector [ r ]
		}
	}
	func normal ( let y: Buffer, let u: Buffer, let s: Buffer ) {
		let n: Int = y.scalar.count
		let W: [UInt16] = [UInt16](count: y.scalar.count, repeatedValue: 0)
		let N: [Float] = [Float](count: y.scalar.count, repeatedValue: 0)
		
		assert(y.scalar.count==u.scalar.count)
		assert(y.scalar.count==s.scalar.count)
		
		arc4random_buf(UnsafeMutablePointer<Void>(W), sizeof(UInt16)*W.count)
		vDSP_vfltu16(W, 1, UnsafeMutablePointer<Float>(N), 1, vDSP_Length(n))
		
		vDSP_vsadd(UnsafePointer<Float>(N).advancedBy(0/2), 1, [Float(1.0)], UnsafeMutablePointer<Float>(N), 1, vDSP_Length(n/2))
		vDSP_vsmul(UnsafePointer<Float>(N).advancedBy(n/2), 1, [Float(2.0)], UnsafeMutablePointer<Float>(N).advancedBy(n/2), 1, vDSP_Length(n/2))
		vDSP_vsdiv(UnsafePointer<Float>(N).advancedBy(0/2), 1, [Float(65536.0)], UnsafeMutablePointer<Float>(N).advancedBy(0/2), 1, vDSP_Length(n))
		
		vvlogf(UnsafeMutablePointer<Float>(N), UnsafePointer<Float>(N), [Int32(n/2)])
		vDSP_vsmul(N, 1, [Float(-2.0)], UnsafeMutablePointer<Float>(N), 1, vDSP_Length(n/2))
		vvsqrtf(UnsafeMutablePointer<Float>(N), UnsafePointer<Float>(N), [Int32(n/2)])
		
		vvcospif(y.scalar.baseAddress.advancedBy(0/2), UnsafePointer<Float>(N).advancedBy(n/2), [Int32(n/2)])
		vDSP_vmul(y.scalar.baseAddress.advancedBy(0/2), 1, UnsafePointer<Float>(N), 1, y.scalar.baseAddress.advancedBy(0/2), 1, vDSP_Length(n/2))
		
		vvsinpif(y.scalar.baseAddress.advancedBy(n/2), UnsafePointer<Float>(N).advancedBy(n/2), [Int32(n/2)])
		vDSP_vmul(y.scalar.baseAddress.advancedBy(n/2), 1, UnsafePointer<Float>(N), 1, y.scalar.baseAddress.advancedBy(n/2), 1, vDSP_Length(n/2))
		
		vDSP_vmul(y.scalar.baseAddress, 1, s.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(n))
		vDSP_vadd(y.scalar.baseAddress, 1, u.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(n))
		
	}
	func pdf ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer ) {
		vDSP_vsub(u.scalar.baseAddress, 1, x.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))			//y <- x - u
		vDSP_vdiv(s.scalar.baseAddress, 1, y.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))			//y <- y/s = (x-u)/s
		vDSP_vsq(y.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))										//y <- y^2 = ((x-u)^2)/(s^2)
		vDSP_vsdiv(y.scalar.baseAddress, 1, [Float(-2.0)], y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))						//y <- y/2 = -((x-u)^2)/(2*(s^2))
		vvexpf(y.scalar.baseAddress, y.scalar.baseAddress, [Int32(y.scalar.count)])													//y <- exp(y) = exp(-((x-u)^2)/(2*(s^2)))
		vDSP_vdiv(s.scalar.baseAddress, 1, y.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))			//y <- y/s = (1/s)*exp(-((x-u)^2)/(2*(s^2)))
		vDSP_vsmul(y.scalar.baseAddress, 1, [Float(0.5*M_2_SQRTPI*M_SQRT1_2)], y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))	//y <- y/sqrt(2*pi) = (1/s/sqrt(2*pi))*exp(-((x-u)^2)/(2*(s^2)))
	}
	func cdf ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer ) {
		assert(y.scalar.count==x.scalar.count)
		assert(y.scalar.count==u.scalar.count)
		assert(y.scalar.count==s.scalar.count)
		vDSP_vsub(x.scalar.baseAddress, 1, u.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
		vDSP_vsmul(y.scalar.baseAddress, 1, [Float(M_SQRT1_2)], y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
		dispatch_apply(4, cpuComputer.dispatch.queue) {(let index: Int)in
			let width: Int = y.scalar.count / 4
			(0..<width).forEach {
				let offset = width * index + $0
				y.scalar[offset] = erfcf(y.scalar[offset])
			}
		}
		vDSP_vsdiv(y.scalar.baseAddress, 1, [Float(2.0)], y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
	}
	func tdf ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer ) {
		assert(y.scalar.count==x.scalar.count)
		assert(y.scalar.count==u.scalar.count)
		assert(y.scalar.count==s.scalar.count)
		vDSP_vsub(u.scalar.baseAddress, 1, x.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
		vDSP_vsmul(y.scalar.baseAddress, 1, [Float(M_SQRT1_2)], y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
		dispatch_apply(4, cpuComputer.dispatch.queue) {(let index: Int)in
			let width: Int = y.scalar.count / 4
			(0..<width).forEach {
				let offset = width * index + $0
				y.scalar[offset] = erfcf(y.scalar[offset])
			}
		}
		vDSP_vsdiv(y.scalar.baseAddress, 1, [Float(2.0)], y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
	}
	func sigmoid ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer ) {
		assert(y.scalar.count==x.scalar.count)
		assert(y.scalar.count==u.scalar.count)
		assert(y.scalar.count==s.scalar.count)
		vDSP_vsub(u.scalar.baseAddress, 1, x.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
		vDSP_vdiv(s.scalar.baseAddress, 1, y.scalar.baseAddress, 1, y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
		vvtanf(y.scalar.baseAddress, y.scalar.baseAddress, [Int32(y.scalar.count)])
		vDSP_vsmsa(y.scalar.baseAddress, 1, [Float(0.5)], [Float(0.5)], y.scalar.baseAddress, 1, vDSP_Length(y.scalar.count))
	}
	func sync ( let task: (Void->Void) ) {
		dispatch_sync(dispatch.queue, task)
	}
	func async ( let task: (Void->Void) ) {
		dispatch_group_async(dispatch.group, dispatch.queue, task)
	}
	func enter ( ) {
		dispatch_group_enter(dispatch.group)
	}
	func leave ( ) {
		dispatch_group_leave(dispatch.group)
	}
	func join () {
		dispatch_group_wait(dispatch.group, DISPATCH_TIME_FOREVER)
	}
	func newBuffer( let data data: NSData ) -> Buffer {
		return cpuBuffer(buffer: data)
	}
	func newBuffer( let length length: Int ) -> Buffer {
		return newBuffer(data: NSData(bytes: [UInt8](count: length, repeatedValue: 0), length: length))
	}
	func test() {
		
	}
}
struct cpuBuffer: Buffer {
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