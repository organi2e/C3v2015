//
//  main.swift
//  Experimental
//
//  Created by Kota Nakano on 8/29/16.
//
//
import Accelerate
import Darwin
import Metal
import simd
func tic() -> () -> Double {
	var src: timeval = timeval()
	gettimeofday(&src, nil)
	return {
		var dst: timeval = timeval()
		gettimeofday(&dst, nil)
		defer { src = dst }
		return Double(dst.tv_sec-src.tv_sec)+1.0*1e-6*Double(dst.tv_usec-src.tv_usec)
	}
}

let dispatch: dispatch_queue_t = dispatch_queue_create("label", DISPATCH_QUEUE_SERIAL)

let device: MTLDevice = MTLCreateSystemDefaultDevice()!
let library: MTLLibrary = device.newDefaultLibrary()!
let queue: MTLCommandQueue = device.newCommandQueue()
let sign: MTLComputePipelineState = try!device.newComputePipelineStateWithFunction(library.newFunctionWithName("sign4")!)
let step: MTLComputePipelineState = try!device.newComputePipelineStateWithFunction(library.newFunctionWithName("step4")!)
let tan: MTLComputePipelineState = try!device.newComputePipelineStateWithFunction(library.newFunctionWithName("tan4")!)
let exp: MTLComputePipelineState = try!device.newComputePipelineStateWithFunction(library.newFunctionWithName("exp4")!)

let N: Int = 1 << 10
let P: Int = 256
let a: [Float] = (0..<N).map { (_)in Float(arc4random())/Float(UInt32.max)-0.5}
let b: [Float] = (0..<N).map { (_)in Float(arc4random())/Float(UInt32.max)-0.5}

let mtlA: MTLBuffer = device.newBufferWithBytes(a, length: sizeof(Float)*N, options: .StorageModeShared)
let mtlB: MTLBuffer = device.newBufferWithBytes(b, length: sizeof(Float)*N, options: .StorageModeShared)
let mtlC: MTLBuffer = device.newBufferWithLength(sizeof(Float)*N, options: .StorageModeShared)

let group: MTLSize = MTLSize(width: N/4, height: 1, depth: 1)
let local: MTLSize = MTLSize(width: 1, height: 1, depth: 1)
let mtltoc = tic()

for p in 1...P {
	let command = queue.commandBuffer()
	var encoder = command.computeCommandEncoder()
	encoder.setComputePipelineState(tan)
	encoder.setBuffer(mtlC, offset: 0, atIndex: 0)
	encoder.setBuffer(mtlA, offset: 0, atIndex: 1)
	encoder.dispatchThreadgroups(group, threadsPerThreadgroup: local)
	encoder.endEncoding()
	command.commit()
	if p == P { command.waitUntilCompleted(); print("wait") }
}

print(Double(N*P)/mtltoc()/1_000_000_000.0, "GFLOPS")

let length: vDSP_Length = vDSP_Length(N)
let cputoc = tic()
for p in 1...P {
	/*
	vDSP_vneg(a, 1, UnsafeMutablePointer<Float>(b), 1, length)
	vDSP_vthrsc(b, 1, [Float(0.0)], [Float(0.5)], UnsafeMutablePointer<Float>(b), 1, length)
	vDSP_vneg(b, 1, UnsafeMutablePointer<Float>(b), 1, length)
	vDSP_vsadd(b, 1, [Float(0.5)], UnsafeMutablePointer<Float>(b), 1, length)
	*/
	/*
	let length: vDSP_Length = vDSP_Length(min(a.count, b.count))
	let cache: [Float] = [Float](count: Int(length), repeatedValue: 0)
	vDSP_vthrsc(a, 1, [Float(0.0)], [Float( 0.5)], UnsafeMutablePointer<Float>(b), 1, length)
	vDSP_vneg(a, 1, UnsafeMutablePointer<Float>(cache), 1, length)
	vDSP_vthrsc(UnsafeMutablePointer<Float>(cache), 1, [Float(0.0)], [Float(-0.5)], UnsafeMutablePointer<Float>(cache), 1, length)
	vDSP_vadd(UnsafeMutablePointer<Float>(cache), 1, UnsafeMutablePointer<Float>(b), 1, UnsafeMutablePointer<Float>(b), 1, length)
	*/
	vvtanpif(UnsafeMutablePointer<Float>(b), a, [Int32(N)])
}
print(Double(N*P)/cputoc()/1_000_000_000.0, "GFLOPS")

let smdtoc = tic()
for p in 1...P {
	var aref: UnsafeMutablePointer<float4> = UnsafeMutablePointer<float4>(a)
	var bref: UnsafeMutablePointer<float4> = UnsafeMutablePointer<float4>(b)
	
	(0..<N/4).forEach {
		bref[$0] = vtanpif(aref[$0])
	}
}
print(Double(N*P)/smdtoc()/1_000_000_000.0, "GFLOPS")

let gcd = tic()
for p in 1...P {
	dispatch_apply(N/4, dispatch) {
		var aref: UnsafeMutablePointer<float4> = UnsafeMutablePointer<float4>(a)
		var bref: UnsafeMutablePointer<float4> = UnsafeMutablePointer<float4>(b)
		bref[$0] = vtanpif(aref[$0])
	}
}
print(Double(N*P)/gcd()/1_000_000_000.0, "GFLOPS")


/*
let gemmfunc1x1: MTLFunction = library.newFunctionWithName("gemm1x1")!
let pipeline1x1: MTLComputePipelineState = try!device.newComputePipelineStateWithFunction(gemmfunc1x1)
let gemmfunc4x4: MTLFunction = library.newFunctionWithName("gemm4x4")!
let pipeline4x4: MTLComputePipelineState = try!device.newComputePipelineStateWithFunction(gemmfunc4x4)

let M: Int = 1024
let K: Int = 1024
let N: Int = 1024

let P: Int = 16

let a: [Float] = (0..<M*K).map{(_)in Float(arc4random())/Float(UInt32.max)}
let b: [Float] = (0..<K*N).map{(_)in Float(arc4random())/Float(UInt32.max)}
let c: [Float] = [Float](count: M*N, repeatedValue: 0)

let mtlA: MTLBuffer = device.newBufferWithLength(sizeof(Float)*a.count, options: .StorageModeShared)
let mtlB: MTLBuffer = device.newBufferWithLength(sizeof(Float)*b.count, options: .StorageModeShared)
let mtlC: MTLBuffer = device.newBufferWithLength(sizeof(Float)*c.count, options: .StorageModeShared)
*/