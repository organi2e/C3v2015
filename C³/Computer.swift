//
//  Factory.swift
//  C³
//
//  Created by Kota Nakano on 6/6/16.
//
//
import Metal
import simd

internal class Computer {
	
	let platform: Platform
	
	let common: (
		device: MTLDevice,
		library: MTLLibrary,
		queue: MTLCommandQueue
	)?
	
	init ( let platform required: Platform ) throws {
		if required == .GPU, let device: MTLDevice = MTLCreateSystemDefaultDevice() {
			var pipelines: [String: MTLComputePipelineState] = [:]
			guard let path: String = Config.bundle.pathForResource(Config.metal.name, ofType: Config.metal.ext) else {
				throw MetalError.LibraryNotAvailable
			}
			let library: MTLLibrary = try device.newLibraryWithFile(path)
			try library.functionNames.forEach {
				if let function: MTLFunction = library.newFunctionWithName($0) {
					pipelines[$0] = try device.newComputePipelineStateWithFunction(function)
				}
			}
			
			common = (device: device, library: library, queue: device.newCommandQueue())
			platform = .GPU
		} else {
			common = nil
			platform = .CPU
		}
	}
	
	internal func gemm ( let Y: Buffer, let alpha: Float, let A: Buffer, let X: Buffer, let beta: Float, let C: Buffer ) {
		
	}
	
	internal func newBuffer ( let length length: Int ) -> Buffer {
		return platform == .GPU ? Buffer() : Buffer()
	}
	internal func newBuffer ( let data data: NSData ) -> Buffer {
		return platform == .GPU ? Buffer() : Buffer()
	}
	internal func newCommandBuffer() -> MTLCommandBuffer? {
		return common?.queue.commandBuffer()
	}
}
