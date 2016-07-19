//
//  mtlComputer.swift
//  C³
//
//  Created by Kota Nakano on 7/18/16.
//
//

import Foundation
import Metal
import simd

public class mtlComputer: cpuComputer {
	
	public enum Error: ErrorType {
		case DeviceNotFound
		case LibraryNotAvailable
		case PipelineNotAvailable(function: String)
	}
	
	struct Pipelines {
		let add: MTLComputePipelineState
		let sub: MTLComputePipelineState
		let mul: MTLComputePipelineState
		let div: MTLComputePipelineState
		let pdf: MTLComputePipelineState
		let cdf: MTLComputePipelineState
		let gemv: MTLComputePipelineState
		let normal: MTLComputePipelineState
		let sigmoid: MTLComputePipelineState
	};
	
	let device: MTLDevice
	let queue: MTLCommandQueue
	let pipelines: Pipelines
		
	public init ( let device: MTLDevice ) throws {
		
		guard let path: String = Config.bundle.pathForResource(Config.metal.name, ofType: Config.metal.ext) else {
			throw Error.LibraryNotAvailable
		}
		let library: MTLLibrary = try device.newLibraryWithFile(path)
		let pipeline: String throws -> MTLComputePipelineState = {
			guard let function: MTLFunction = library.newFunctionWithName($0) else {
				throw Error.PipelineNotAvailable(function: $0)
			}
			return try device.newComputePipelineStateWithFunction(function)
		}
		self.pipelines = Pipelines(add: try pipeline("add"),
		                           sub: try pipeline("sub"),
		                           mul: try pipeline("mul"),
		                           div: try pipeline("div"),
		                           pdf: try pipeline("pdf"),
		                           cdf: try pipeline("cdf"),
		                           gemv: try pipeline("gemv"),
		                           normal: try pipeline("normal"),
		                           sigmoid: try pipeline("sigmoid")
		)
		self.device = device
		self.queue = device.newCommandQueue()
	}
	override func gemv ( let y y: Buffer, let beta: Float, let a: Buffer, let x: Buffer, let alpha: Float, let n: Int, let m: Int, let trans: Bool ) {
		if	let x: mtlBuffer = x as? mtlBuffer where x.mtl.device === device,
			let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let a: mtlBuffer = a as? mtlBuffer where a.mtl.device === device {
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(pipelines.gemv)
			encoder.setBuffer(y.mtl, offset: 0, atIndex: 0)
			encoder.setBytes([beta], length: sizeof(Float), atIndex: 1)
			encoder.setBuffer(a.mtl, offset: 0, atIndex: 2)
			encoder.setBuffer(x.mtl, offset: 0, atIndex: 3)
			encoder.setBytes([alpha], length: sizeof(Float), atIndex: 4)
			encoder.setBytes([UInt(trans)], length: sizeof(UInt), atIndex: 5)
			encoder.setThreadgroupMemoryLength(sizeof(Float)*n, atIndex: 0)
			encoder.dispatchThreadgroups(MTLSize(width: m/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: n/4, height: 1, depth: 1))
			encoder.endEncoding()
			command.commit()
		} else {
			async {
				super.gemv(y: y, beta: beta, a: a, x: x, alpha: alpha, n: n, m: m, trans: trans)
			}
		}
	}
	override func normal ( let y: Buffer, let u: Buffer, let s: Buffer, let sync flag: Bool = false ) {
		
		assert(y.scalar.count==u.scalar.count)
		assert(y.scalar.count==s.scalar.count)
		
		if	let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let u: mtlBuffer = u as? mtlBuffer where u.mtl.device === device,
			let s: mtlBuffer = s as? mtlBuffer where s.mtl.device === device,
			let w: mtlBuffer = newBuffer(length: sizeof(UInt8)*y.scalar.count) as? mtlBuffer {
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			
			arc4random_buf(UnsafeMutablePointer(w.raw.bytes), w.raw.length)
			
			encoder.setComputePipelineState(pipelines.normal)
			encoder.setBuffer(y.mtl, offset: 0, atIndex: 0)
			encoder.setBuffer(u.mtl, offset: 0, atIndex: 1)
			encoder.setBuffer(s.mtl, offset: 0, atIndex: 2)
			encoder.setBuffer(w.mtl, offset: 0, atIndex: 3)
			encoder.dispatchThreadgroups(MTLSize(width: y.scalar.count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
			encoder.endEncoding()
			command.addCompletedHandler {(_)in
				w.mtl.setPurgeableState(.Empty)
			}
			command.commit()
			if flag { command.waitUntilCompleted() }
		} else {
			( flag ? sync : async ) {
				super.normal(y, u: u, s: s, sync: true)
			}
		}
	}
	override func pdf ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer, let sync flag: Bool = false ) {
		
		assert(y.scalar.count==x.scalar.count)
		assert(y.scalar.count==y.scalar.count)
		assert(y.scalar.count==s.scalar.count)
		
		if	let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let x: mtlBuffer = x as? mtlBuffer where x.mtl.device === device,
			let u: mtlBuffer = u as? mtlBuffer where u.mtl.device === device,
			let s: mtlBuffer = s as? mtlBuffer where s.mtl.device === device {
			
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(pipelines.pdf)
			encoder.setBuffer(y.mtl, offset: 0, atIndex: 0)
			encoder.setBuffer(x.mtl, offset: 0, atIndex: 1)
			encoder.setBuffer(u.mtl, offset: 0, atIndex: 2)
			encoder.setBuffer(s.mtl, offset: 0, atIndex: 3)
			encoder.setBytes([Float(0.5*M_2_SQRTPI*M_SQRT1_2)], length: sizeof(Float), atIndex: 4)
			encoder.dispatchThreadgroups(MTLSize(width: y.scalar.count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
			encoder.endEncoding()
			command.commit()
			if flag { command.waitUntilCompleted() }
		} else {
			( flag ? sync : async ) {
				super.pdf(y, x: x, u: u, s: s, sync: true)
			}
		}
	}
	override func cdf ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer, let sync flag: Bool = false ) {
		
		assert(y.scalar.count==x.scalar.count)
		assert(y.scalar.count==y.scalar.count)
		assert(y.scalar.count==s.scalar.count)
		
		if	let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let x: mtlBuffer = x as? mtlBuffer where x.mtl.device === device,
			let u: mtlBuffer = u as? mtlBuffer where u.mtl.device === device,
			let s: mtlBuffer = s as? mtlBuffer where s.mtl.device === device {
		} else {
			( flag ? sync : async ) {
				super.cdf(y, x: x, u: u, s: s, sync: true)
			}
		}
	}
	override func sync ( let task: (Void->Void) ) {
		let command: MTLCommandBuffer = queue.commandBuffer()
		command.addCompletedHandler { ( _ ) in
			task()
		}
		command.commit()
		command.waitUntilCompleted()
	}
	override func async ( let task: (Void->Void) ) {
		let command: MTLCommandBuffer = queue.commandBuffer()
		command.addCompletedHandler { ( _ ) in
			task()
		}
		command.commit()
	}
	override func join () {
		let command: MTLCommandBuffer = queue.commandBuffer()
		command.commit()
		command.waitUntilCompleted()
	}
	override func newBuffer( let data data: NSData ) -> Buffer {
		let mtl: MTLBuffer = device.newBufferWithBytes(data.bytes, length: data.length, options: .CPUCacheModeDefaultCache)
		return mtlBuffer(buffer: mtl)
	}
	override func newBuffer( let length length: Int ) -> Buffer {
		let mtl: MTLBuffer = device.newBufferWithLength(length, options: .CPUCacheModeDefaultCache)
		return mtlBuffer(buffer: mtl)
	}
	override func test() {
		let n = 1 << 22
		let y = newBuffer(length: sizeof(Float)*n)
		let u = newBuffer(length: sizeof(Float)*n)
		let s = newBuffer(length: sizeof(Float)*n)
		for k in 0..<n {
			u.scalar[k] = 100
			s.scalar[k] = 500
		}
		super.normal(y, u: u, s: s)
		join()
		let mu: Float = y.scalar.reduce(0.0){$0+$1} / Float(n)
		let sigma: Float = y.scalar.map{($0-mu)*($0-mu)}.reduce(0){$0+$1} / Float(n)
		print("mu", mu, "sigma", sqrtf(sigma))
	}
}
class mtlBuffer: Buffer {
	let mtl: MTLBuffer
	let raw: NSData
	let stream: UnsafeMutableBufferPointer<UInt8>
	let scalar: UnsafeMutableBufferPointer<Float>
	let vector: UnsafeMutableBufferPointer<float4>
	let matrix: UnsafeMutableBufferPointer<float4x4>
	init ( let buffer: MTLBuffer ) {
		mtl = buffer
		raw = NSData(bytesNoCopy: mtl.contents(), length: mtl.length, freeWhenDone: false)
		stream = UnsafeMutableBufferPointer<UInt8>(start: UnsafeMutablePointer<UInt8>(raw.bytes), count: raw.length/sizeof(UInt8))
		scalar = UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(raw.bytes), count: raw.length/sizeof(Float))
		vector = UnsafeMutableBufferPointer<float4>(start: UnsafeMutablePointer<float4>(raw.bytes), count: raw.length/sizeof(float4))
		matrix = UnsafeMutableBufferPointer<float4x4>(start: UnsafeMutablePointer<float4x4>(raw.bytes), count: raw.length/sizeof(float4x4))
	}
}