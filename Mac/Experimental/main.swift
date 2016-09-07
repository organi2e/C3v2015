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

let NOHINT: la_hint_t = la_hint_t(LA_NO_HINT)
let ATTR: la_attribute_t = la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)

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

let N: Int = 1 << 20
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
	encoder.setComputePipelineState(sign)
	encoder.setBuffer(mtlC, offset: 0, atIndex: 0)
	encoder.setBuffer(mtlA, offset: 0, atIndex: 1)
	encoder.dispatchThreadgroups(group, threadsPerThreadgroup: local)
	encoder.endEncoding()
	command.commit()
	if p == P { command.waitUntilCompleted(); print("wait") }
}

print(Double(N*P)/mtltoc()/1_000_000_000.0, "GFLOPS")

do {
	let length: vDSP_Length = vDSP_Length(N)
	let cache: [Float] = [Float](count: Int(length), repeatedValue: 0)
	
	var zero: Float = 0.0
	var posi: Float = 0.5
	var nega: Float = -0.5
	
	let cputoc = tic()
	for p in 1...P {
		vDSP_vthrsc(a, 1, &zero, &posi, UnsafeMutablePointer<Float>(b), 1, length)
		vDSP_vneg(a, 1, UnsafeMutablePointer<Float>(cache), 1, length)
		vDSP_vthrsc(UnsafeMutablePointer<Float>(cache), 1, &zero, &nega, UnsafeMutablePointer<Float>(cache), 1, length)
		vDSP_vadd(UnsafeMutablePointer<Float>(cache), 1, UnsafeMutablePointer<Float>(b), 1, UnsafeMutablePointer<Float>(b), 1, length)
	}
	print(Double(N*P)/cputoc()/1_000_000_000.0, "GFLOPS (vDSP sign, vthrsc)")
}

do {
	let length: vDSP_Length = vDSP_Length(N)
	let cache: [Float] = [Float](count: Int(length), repeatedValue: 0)
	
	var zero: Float = 0.0
	var posi: Float = 0.5
	var nega: Float = -0.5
	
	let cputoc = tic()
	for p in 1...P {
		vDSP_vlim(a, 1, &zero, &posi, UnsafeMutablePointer<Float>(b), 1, length)
		vDSP_vneg(a, 1, UnsafeMutablePointer<Float>(cache), 1, length)
		vDSP_vlim(UnsafeMutablePointer<Float>(cache), 1, &zero, &nega, UnsafeMutablePointer<Float>(cache), 1, length)
		vDSP_vadd(UnsafeMutablePointer<Float>(cache), 1, UnsafeMutablePointer<Float>(b), 1, UnsafeMutablePointer<Float>(b), 1, length)
	}
	print(Double(N*P)/cputoc()/1_000_000_000.0, "GFLOPS (vDSP sign, vlim)")
}

do {
	let smdtoc = tic()
	let aref: UnsafeMutablePointer<float4> = UnsafeMutablePointer<float4>(a)
	var bref: UnsafeMutablePointer<float4> = UnsafeMutablePointer<float4>(b)
	for p in 1...P {
		(0..<N/4).forEach {
			bref[$0] = -vector_sign(-aref[$0])
		}
	}
	print(Double(N*P)/smdtoc()/1_000_000_000.0, "GFLOPS (simd sign)")
}

let gcd = tic()
for p in 1...P {
	dispatch_apply(N/4, dispatch) {
		var aref: UnsafeMutablePointer<float4> = UnsafeMutablePointer<float4>(a)
		var bref: UnsafeMutablePointer<float4> = UnsafeMutablePointer<float4>(b)
		bref[$0] = vtanpif(aref[$0])
	}
}
print(Double(N*P)/gcd()/1_000_000_000.0, "GFLOPS")

do {
	let length: vDSP_Length = vDSP_Length(N)
	let cache: [Float] = [Float](count: Int(length), repeatedValue: 0)
	var pi: Float = Float(M_PI)
	let A: la_object_t = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(a), la_count_t(length), 1, 1, NOHINT, nil, ATTR)
	let B: la_object_t = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(b), la_count_t(length), 1, 1, NOHINT, nil, ATTR)
	let cputoc = tic()
	for p in 1...P {
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), 1, la_scale_with_float(la_sum(A, B), pi))
	}
	print(Double(3*N*P)/cputoc()/1_000_000_000.0, "GFLOPS (la_object_t)")
}

do {
	let length: vDSP_Length = vDSP_Length(N)
	let cache: [Float] = [Float](count: Int(length), repeatedValue: 0)
	var pi: Float = Float(M_PI)
	let cputoc = tic()
	for p in 1...P {
		vDSP_vasm(a, 1, b, 1, &pi, UnsafeMutablePointer<Float>(cache), 1, length)
	}
	print(Double(3*N*P)/cputoc()/1_000_000_000.0, "GFLOPS (vDSP)")
}

do {
	let length: vDSP_Length = vDSP_Length(N)
	let cache: [Float] = a
	var pi: Float = Float(M_PI)
	let len: Int32 = Int32(length)
	let cputoc = tic()
	for p in 1...P {
		cblas_saxpy(len, pi, a, 1, UnsafeMutablePointer<Float>(b), 1)
	}
	print(Double(3*N*P)/cputoc()/1_000_000_000.0, "GFLOPS (cblas)")
}

do {
	let length: vDSP_Length = vDSP_Length(N)
	let cache: [Float] = a
	var pi: Float = Float(M_PI)
	let len: Int32 = Int32(length)
	let cputoc = tic()
	for p in 1...P {
		vDSP_vmul(a, 1, b, 1, UnsafeMutablePointer<Float>(cache), 1, length)
	}
	print(Double(3*N*P)/cputoc()/1_000_000_000.0, "GFLOPS (vDSP) vector mul")
}

do {
	let length: vDSP_Length = vDSP_Length(N)
	let cache: [Float] = a
	var pi: Float = Float(M_PI)
	let len: Int32 = Int32(length)
	let cputoc = tic()
	for p in 1...P {
		cblas_ssbmv(CblasRowMajor, CblasLower, len, 0, 1, a, 1, b, 1, 0, UnsafeMutablePointer<Float>(cache), 1)
		//cblas_saxpy(len, pi, a, 1, UnsafeMutablePointer<Float>(b), 1)
	}
	print(Double(3*N*P)/cputoc()/1_000_000_000.0, "GFLOPS (cblas)")
}

do {
	let a = la_splat_from_float(0, ATTR)
	let b = la_splat_from_float(0, ATTR)
	la_sum(a, b)
}