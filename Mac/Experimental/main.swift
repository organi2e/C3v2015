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
let pdf4: MTLComputePipelineState = try!device.newComputePipelineStateWithFunction(library.newFunctionWithName("pdf4")!)
let cauchy4: MTLComputePipelineState = try!device.newComputePipelineStateWithFunction(library.newFunctionWithName("cauchy4")!)

let N: Int = 1 << 20
let P: Int = 256
var a: [Float] = (0..<N).map { (_)in Float(arc4random())/Float(UInt32.max)-0.5}
var b: [Float] = (0..<N).map { (_)in Float(arc4random())/Float(UInt32.max)-0.5}
var c: [Float] = (0..<N).map { (_)in Float(arc4random())/Float(UInt32.max)-0.5}

let mtlA: MTLBuffer = device.newBufferWithBytes(a, length: sizeof(Float)*N, options: .StorageModeShared)
let mtlB: MTLBuffer = device.newBufferWithBytes(b, length: sizeof(Float)*N, options: .StorageModeShared)
let mtlC: MTLBuffer = device.newBufferWithLength(sizeof(Float)*N, options: .StorageModeShared)

let group: MTLSize = MTLSize(width: N/4, height: 1, depth: 1)
let local: MTLSize = MTLSize(width: 1, height: 1, depth: 1)

do {
	let mtltoc = tic()
	let command = queue.commandBuffer()
	let encoder = command.computeCommandEncoder()
	for p in 1...P {
		encoder.setComputePipelineState(sign)
		encoder.setBuffer(mtlC, offset: 0, atIndex: 0)
		encoder.setBuffer(mtlA, offset: 0, atIndex: 1)
		encoder.dispatchThreadgroups(group, threadsPerThreadgroup: local)
	}
	encoder.endEncoding()
	command.commit()
	command.waitUntilCompleted()
	print(Double(N*P)/mtltoc()/1_000_000_000.0, "GFLOPS (metal sign)")
}

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
	let cputoc = tic()
	let length: vDSP_Length = vDSP_Length(N)
	
	var len: Int32 = Int32(N)
	
	var zero: Float = 0
	var posi: Float = 0.5
	var nega: Float = -0.5
	for _ in 1...P {
		vDSP_vneg(a, 1, &b, 1, length)
		vDSP_vlim(a, 1, &zero, &posi, &a, 1, length)
		vDSP_vlim(b, 1, &zero, &nega, &b, 1, length)
		vDSP_vadd(a, 1, b, 1, &a, 1, length)//Δ.χ = sign(δ)
	
		vDSP_vmul(a, 1, b, 1, &b, 1, length)//Δ.σ = μ * λ
		vDSP_vsq(b, 1, &c, 1, length)//Δ.μ = ( μ * λ ) ^ 2
		cblas_sscal(len, nega, &c, 1)//Δ.μ = -0.5 * ( μ * λ ) ^ 2
	
		vvexpf(&a, a, &len)
		cblas_sscal(len, Float(0.5 * M_2_SQRTPI * M_SQRT1_2), &b, 1)
		vDSP_vmul(c, 1, b, 1, &a, 1, length)
	
		vDSP_vmul(a, 1, c, 1, &b, 1, length)
		vDSP_vmul(b, 1, c, 1, &b, 1, length)
		vDSP_vmul(c, 1, a, 1, &c, 1, length)
		vDSP_vneg(c, 1, &c, 1, length)
	}
	print(Double(N*P)/cputoc()/1_000_000_000.0, "GFLOPS (gaussian, vDSP)")
}

do {
	let group: MTLSize = MTLSize(width: N/4, height: 1, depth: 1)
	let local: MTLSize = MTLSize(width: 1, height: 1, depth: 1)
	let command = queue.commandBuffer()
	let encoder = command.computeCommandEncoder()
	let cputoc = tic()
	for p in 1...P {
		encoder.setComputePipelineState(pdf4)
		encoder.setBuffer(mtlC, offset: 0, atIndex: 0)
		encoder.setBuffer(mtlC, offset: 0, atIndex: 1)
		encoder.setBuffer(mtlA, offset: 0, atIndex: 2)
		encoder.setBuffer(mtlB, offset: 0, atIndex: 3)
		encoder.dispatchThreadgroups(group, threadsPerThreadgroup: local)
	}
	encoder.endEncoding()
	command.commit()
	command.waitUntilCompleted()
	print(Double(N*P)/cputoc()/1_000_000_000.0, "GFLOPS (gaussian, mtl)")
}

do {
	let cputoc = tic()
	let command = queue.commandBuffer()
	var encoder = command.computeCommandEncoder()
	for p in 1...P {
		encoder.setComputePipelineState(cauchy4)
		encoder.setBuffer(mtlC, offset: 0, atIndex: 0)
		encoder.setBuffer(mtlC, offset: 0, atIndex: 1)
		encoder.setBuffer(mtlA, offset: 0, atIndex: 2)
		encoder.setBuffer(mtlB, offset: 0, atIndex: 3)
		encoder.dispatchThreadgroups(group, threadsPerThreadgroup: local)
	}
	encoder.endEncoding()
	command.commit()
	command.waitUntilCompleted()
	print(Double(N*P)/cputoc()/1_000_000_000.0, "GFLOPS (cauchy, mtl)")
}

do {
	let cputoc = tic()
	
	
	let length: vDSP_Length = vDSP_Length(N)
	
	var len: Int32 = Int32(N)
	
	var one: Float = 1.0
	var zero: Float = 0
	var posi: Float = 0.5
	var nega: Float = -0.5
	
	for _ in 1...P {
		vDSP_vneg(a, 1, &c, 1, length)
		vDSP_vlim(b, 1, &zero, &posi, &b, 1, length)
		vDSP_vlim(c, 1, &zero, &nega, &c, 1, length)
		vDSP_vadd(b, 1, c, 1, &a, 1, length)
	
		vDSP_vmul(b, 1, c, 1, &c, 1, length)
		vDSP_vsq(c, 1, &c, 1, length)
		vDSP_vsadd(b, 1, &one, &c, 1, length)
	
		cblas_sscal(len, Float(M_1_PI), &c, 1)
		vvdivf(&b, a, c, &len)
	
		vDSP_vmul(b, 1, a, 1, &b, 1, length)
		vDSP_vmul(b, 1, c, 1, &c, 1, length)
		vDSP_vneg(c, 1, &c, 1, length)
	}
	print(Double(N*P)/cputoc()/1_000_000_000.0, "GFLOPS (cauchy, vDSP)")
}

