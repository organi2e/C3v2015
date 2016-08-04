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
		let sq: MTLComputePipelineState
		let sqrt: MTLComputePipelineState
		let exp: MTLComputePipelineState
		let pdf: MTLComputePipelineState
		let cdf: MTLComputePipelineState
		let gemv: MTLComputePipelineState
		let gemm: MTLComputePipelineState
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
		                           sq: try pipeline("sq"),
		                           sqrt: try pipeline("sqrt"),
		                           exp: try pipeline("exp"),
		                           pdf: try pipeline("pdf"),
		                           cdf: try pipeline("cdf"),
		                           gemv: try pipeline("gemv"),
		                           gemm: try pipeline("gemm"),
		                           normal: try pipeline("normal"),
		                           sigmoid: try pipeline("sigmoid")
		)
		self.device = device
		self.queue = device.newCommandQueue()
	}
	override func fill( let to y: Buffer, let from x: [Float], let sync flag: Bool = false ) {
		assert(y.scalar.count==x.count)
		if	let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device {
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLBlitCommandEncoder = command.blitCommandEncoder()
			let cache: MTLBuffer = device.newBufferWithBytes(UnsafePointer<Void>(x), length: y.mtl.length, options: .CPUCacheModeDefaultCache)
			encoder.copyFromBuffer(cache, sourceOffset: 0, toBuffer: y.mtl, destinationOffset: 0, size: y.mtl.length)
			encoder.endEncoding()
			command.addCompletedHandler {(_)in
				cache.setPurgeableState(.Empty)
			}
			command.commit()
			if flag { command.waitUntilCompleted() }
		} else {
			( flag ? sync : async ) {
				super.fill(to: y, from: x)
			}
		}
	}
	override func copy( let to y: Buffer, let from x: Buffer, let sync flag: Bool = false ) {
		assert(y.scalar.count==y.scalar.count)
		if	let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let x: mtlBuffer = x as? mtlBuffer where x.mtl.device === device
		{
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLBlitCommandEncoder = command.blitCommandEncoder()
			encoder.copyFromBuffer(x.mtl, sourceOffset: 0, toBuffer: y.mtl, destinationOffset: 0, size: y.mtl.length)
			encoder.endEncoding()
			command.commit()
			if flag { command.waitUntilCompleted() }
		} else {
			( flag ? sync : async ) {
				super.copy(to: y, from: x)
			}
		}
	}
	override func clear ( let y: Buffer, let sync flag: Bool = false ) {
		if	let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device {
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLBlitCommandEncoder = command.blitCommandEncoder()
			encoder.fillBuffer(y.mtl, range: NSRange(location: 0, length: y.mtl.length), value: 0)
			encoder.endEncoding()
			command.commit()
			if flag { command.waitUntilCompleted() }
		} else {
			( flag ? sync : async ) {
				super.clear(y, sync: true)
			}
		}
	}
	override func gemv ( let y: Buffer, let a: Buffer, let x: Buffer, let alpha: Float, let beta: Float, let transpose: Bool, let sync: Bool = false ) {
		let m: Int = y.scalar.count
		let n: Int = x.scalar.count
		assert(m*n==a.scalar.count)
		if	let x: mtlBuffer = x as? mtlBuffer where x.mtl.device === device,
			let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let a: mtlBuffer = a as? mtlBuffer where a.mtl.device === device {
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(pipelines.gemv)
			encoder.setBuffer(y.mtl, offset: 0, atIndex: 0)
			encoder.setBuffer(a.mtl, offset: 0, atIndex: 1)
			encoder.setBuffer(x.mtl, offset: 0, atIndex: 2)
			encoder.setBytes([alpha], length: sizeof(Float), atIndex: 3)
			encoder.setBytes([beta], length: sizeof(Float), atIndex: 4)
			encoder.setBytes([UInt(transpose)], length: sizeof(UInt), atIndex: 5)
			encoder.setThreadgroupMemoryLength(sizeof(Float)*n, atIndex: 0)
			encoder.dispatchThreadgroups(MTLSize(width: m/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: n/4, height: 1, depth: 1))
			encoder.endEncoding()
			command.commit()
		} else {
			async {
				super.gemv(y, a: a, x: x, alpha: alpha, beta: beta, transpose: transpose, sync: true)
			}
		}
	}
	override func gemm ( let y: Buffer, let a: Buffer, let x: Buffer, let alpha: Float, let beta: Float, let dim: (Int, Int, Int), let transpose: (Bool, Bool), let sync: Bool ) {
		
		assert(y.scalar.count==dim.0*dim.2)
		assert(a.scalar.count==dim.0*dim.1)
		assert(x.scalar.count==dim.1*dim.2)
		
		if	let x: mtlBuffer = x as? mtlBuffer where x.mtl.device === device,
			let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let a: mtlBuffer = a as? mtlBuffer where a.mtl.device === device {
			
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			
			encoder.setComputePipelineState(pipelines.gemm)
			encoder.setBuffer(y.mtl, offset: 0, atIndex: 0)
			encoder.setBuffer(a.mtl, offset: 0, atIndex: 1)
			encoder.setBuffer(x.mtl, offset: 0, atIndex: 2)
			encoder.setBytes([UInt32(dim.0)], length: sizeof(UInt32), atIndex: 3)
			encoder.setBytes([UInt32(dim.1)], length: sizeof(UInt32), atIndex: 4)
			encoder.setBytes([UInt32(dim.2)], length: sizeof(UInt32), atIndex: 5)
			
			/*
			encoder.setBytes([UInt32(Int(dim.1/4))], length: sizeof(UInt32), atIndex: 5)
			encoder.setThreadgroupMemoryLength(sizeof(Float)*4*dim.1, atIndex: 0)
			encoder.dispatchThreadgroups(MTLSize(width: dim.2/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: dim.0/4, height: 1, depth: 1))
			*/
			
			let bx = 8
			let by = 8
			encoder.setThreadgroupMemoryLength(sizeof(Float)*bx*by, atIndex: 0)
			encoder.setThreadgroupMemoryLength(sizeof(Float)*bx*by, atIndex: 1)
			encoder.dispatchThreadgroups(MTLSize(width: dim.0/bx, height: dim.1/by, depth: 1), threadsPerThreadgroup: MTLSize(width: bx, height: by, depth: 1))
			
			encoder.endEncoding()
			command.commit()
			
		} else {
			assertionFailure()
		}
	}
	override func normal ( let y: Buffer, let u: Buffer, let s: Buffer, let sync flag: Bool = false ) {
		
		assert(y.scalar.count==u.scalar.count)
		assert(y.scalar.count==s.scalar.count)
		
		if	let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let u: mtlBuffer = u as? mtlBuffer where u.mtl.device === device,
			let s: mtlBuffer = s as? mtlBuffer where s.mtl.device === device,
			let w: mtlBuffer = newBuffer(length: sizeof(UInt32)*y.scalar.count) as? mtlBuffer {
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
	override func sq( let y: Buffer, let _ x: Buffer, let sync flag: Bool = false ) {
		
		assert(y.scalar.count==x.scalar.count)
		
		if	let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let x: mtlBuffer = x as? mtlBuffer where x.mtl.device === device
		{
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(pipelines.sq)
			encoder.setBuffer(y.mtl, offset: 0, atIndex: 0)
			encoder.setBuffer(x.mtl, offset: 0, atIndex: 1)
			encoder.dispatchThreadgroups(MTLSize(width: y.scalar.count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
			encoder.endEncoding()
			command.commit()
			if flag { command.waitUntilCompleted() }
		} else {
			( flag ? sync : async ) {
				super.sq(y, x, sync: true)
			}
		}
	}
	override func sqrt( let y: Buffer, let _ x: Buffer, let sync flag: Bool = false ) {
		
		assert(y.scalar.count==x.scalar.count)
		
		if	let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let x: mtlBuffer = x as? mtlBuffer where x.mtl.device === device
		{
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(pipelines.sqrt)
			encoder.setBuffer(y.mtl, offset: 0, atIndex: 0)
			encoder.setBuffer(x.mtl, offset: 0, atIndex: 1)
			encoder.dispatchThreadgroups(MTLSize(width: y.scalar.count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
			encoder.endEncoding()
			command.commit()
			if flag { command.waitUntilCompleted() }
		} else {
			( flag ? sync : async ) {
				super.sqrt(y, x, sync: true)
			}
		}
	}
	override func exp( let y: Buffer, let _ x: Buffer, let sync flag: Bool = false ) {
		
		assert(y.scalar.count==x.scalar.count)
		
		if	let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let x: mtlBuffer = x as? mtlBuffer where x.mtl.device === device
		{
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(pipelines.exp)
			encoder.setBuffer(y.mtl, offset: 0, atIndex: 0)
			encoder.setBuffer(x.mtl, offset: 0, atIndex: 1)
			encoder.dispatchThreadgroups(MTLSize(width: y.scalar.count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
			encoder.endEncoding()
			command.commit()
			if flag { command.waitUntilCompleted() }
		} else {
			( flag ? sync : async ) {
				super.exp(y, x, sync: true)
			}
		}
	}
	override func pdf ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer, let sync flag: Bool = false ) {
		
		assert(y.scalar.count==x.scalar.count)
		assert(y.scalar.count==u.scalar.count)
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
		assert(y.scalar.count==u.scalar.count)
		assert(y.scalar.count==s.scalar.count)
		
		if	let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let x: mtlBuffer = x as? mtlBuffer where x.mtl.device === device,
			let u: mtlBuffer = u as? mtlBuffer where u.mtl.device === device,
			let s: mtlBuffer = s as? mtlBuffer where s.mtl.device === device {
			
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(pipelines.cdf)
			encoder.setBuffer(y.mtl, offset: 0, atIndex: 0)
			encoder.setBuffer(x.mtl, offset: 0, atIndex: 1)
			encoder.setBuffer(u.mtl, offset: 0, atIndex: 2)
			encoder.setBuffer(s.mtl, offset: 0, atIndex: 3)
			encoder.setBytes([Float(M_SQRT1_2)], length: sizeof(Float), atIndex: 4)
			encoder.dispatchThreadgroups(MTLSize(width: y.scalar.count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
			encoder.endEncoding()
			command.commit()
			if flag { command.waitUntilCompleted() }
		} else {
			( flag ? sync : async ) {
				super.cdf(y, x: x, u: u, s: s, sync: true)
			}
		}
	}
	override func sigmoid( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer, let sync flag: Bool = false ) {
		assert(y.scalar.count==x.scalar.count)
		assert(y.scalar.count==u.scalar.count)
		assert(y.scalar.count==s.scalar.count)
		if	let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let x: mtlBuffer = x as? mtlBuffer where x.mtl.device === device,
			let u: mtlBuffer = u as? mtlBuffer where u.mtl.device === device,
			let s: mtlBuffer = s as? mtlBuffer where s.mtl.device === device
		{
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(pipelines.sigmoid)
			encoder.setBuffer(y.mtl, offset: 0, atIndex: 0)
			encoder.setBuffer(x.mtl, offset: 0, atIndex: 1)
			encoder.setBuffer(u.mtl, offset: 0, atIndex: 2)
			encoder.setBuffer(s.mtl, offset: 0, atIndex: 3)
			encoder.dispatchThreadgroups(MTLSize(width: y.scalar.count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
			encoder.endEncoding()
			command.commit()
			if flag { command.waitUntilCompleted() }
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
		let mtl: MTLBuffer = device.newBufferWithBytes(data.bytes, length: data.length, options: .StorageModeShared)
		return mtlBuffer(buffer: mtl)
	}
	override func newBuffer( let length length: Int ) -> Buffer {
		let mtl: MTLBuffer = device.newBufferWithLength(length, options: .StorageModeShared)
		return mtlBuffer(buffer: mtl)
	}
	override func newBuffer( let buffer buffer: [Float] ) -> Buffer {
		let mtl: MTLBuffer = device.newBufferWithBytes(UnsafePointer<Void>(buffer), length: sizeof(Float)*buffer.count, options: .StorageModeShared)
		return mtlBuffer(buffer: mtl)
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