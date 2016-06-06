//
//  Factory.swift
//  C³
//
//  Created by Kota Nakano on 6/6/16.
//
//
import Accelerate
import Metal
import simd

internal class Computer {
	
	let mtl: (
		device: MTLDevice,
		queue: MTLCommandQueue,
		pipeline: [String: MTLComputePipelineState]
	)?
	
	init ( let platform required: Platform ) throws {
		if required == .GPU, let device: MTLDevice = MTLCreateSystemDefaultDevice() {
			var pipeline: [String: MTLComputePipelineState] = [:]
			guard let path: String = Config.bundle.pathForResource(Config.metal.name, ofType: Config.metal.ext) else {
				throw MetalError.LibraryNotAvailable
			}
			let library: MTLLibrary = try device.newLibraryWithFile(path)
			try library.functionNames.forEach {
				if let function: MTLFunction = library.newFunctionWithName($0) {
					pipeline[$0] = try device.newComputePipelineStateWithFunction(function)
				}
			}
			mtl = (
				device: device,
				queue: device.newCommandQueue(),
				pipeline: pipeline
			)
		} else {
			mtl = nil
		}
	}
	
	internal func gemv ( let y y: Buffer, let beta: Float, let a: Buffer, let x: Buffer, let alpha: Float, let n: Int, let m: Int, let trans: Bool ) {
		if let mtl = mtl, pipeline: MTLComputePipelineState = mtl.pipeline["gemv"] {
			let command: MTLCommandBuffer = mtl.queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(pipeline)
			encoder.setBuffer(y.mtl, offset: 0, atIndex: 0)
			encoder.setBytes([beta], length: sizeof(Float), atIndex: 1)
			encoder.setBuffer(a.mtl, offset: 0, atIndex: 2)
			encoder.setBuffer(x.mtl, offset: 0, atIndex: 3)
			encoder.setBytes([alpha], length: sizeof(Float), atIndex: 4)
			encoder.setBytes([boolean_t(UInt(trans))], length: sizeof(boolean_t), atIndex: 5)
			encoder.setThreadgroupMemoryLength(sizeof(Float)*n, atIndex: 0)
			encoder.dispatchThreadgroups(MTLSize(width: m/4, height: 0, depth: 0), threadsPerThreadgroup: MTLSize(width: n/4, height: 0, depth: 0))
			encoder.endEncoding()
			command.commit()
		} else {
			async {
				Computer.gemv(y: y, beta: beta, a: a, x: x, alpha: alpha, n: n, m: m, trans: trans)
			}
		}
	}
	
	internal func newBuffer ( let length length: Int ) -> Buffer {
		return newBuffer(data: NSData(bytes: [UInt8](count: length, repeatedValue: 0), length: length))
	}
	internal func newBuffer ( let data data: NSData ) -> Buffer {
		return mtl == nil ? Buffer(raw: data) : Buffer(mtl: mtl?.device.newBufferWithBytes(data.bytes, length: data.length, options: .CPUCacheModeDefaultCache))
	}
	internal func sync ( let task task: (Void->Void) ) {
		if let command: MTLCommandBuffer = mtl?.queue.commandBuffer() {
			command.addCompletedHandler { ( _ ) in
				task()
			}
			command.commit()
			command.waitUntilCompleted()
		} else {
			task()
		}
	}
	internal func async ( let task task: (Void->Void) ) {
		if let command: MTLCommandBuffer = mtl?.queue.commandBuffer() {
			command.addCompletedHandler { ( _ ) in
				task()
			}
			command.commit()
		} else {
			task()
		}
	}
}
extension Computer {
	internal static func gemv ( let y y: Buffer, let beta: Float, let a: Buffer, let x: Buffer, let alpha: Float, let n: Int, let m: Int, let trans: Bool ) {
		( 0 ..< y.vector.count ).forEach {
			let m: [float4x4] = $0.stride(to: n/4, by: m/4).map{ a.matrix[ $0 ] }
			let v: [float4] = Array<float4>( x.vector )
			let a: float4 = zip ( m, v ).map{ $0 * $1 }.reduce ( float4(0) ) { $0.0 + $0.1 }
			let b: float4 = y.vector [ $0 ]
			y.vector [ $0 ] = alpha * a + beta * b
		}
	}
}