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

protocol Computer {
	func sync ( let task: (Void->Void))
	func async ( let task: (Void->Void))
	func enter ( )
	func leave ( )
	func join ( )
	func gemv ( let y y: Buffer, let beta: Float, let a: Buffer, let x: Buffer, let alpha: Float, let n: Int, let m: Int, let trans: Bool );
	func normal ( let y y: Buffer, let u: Buffer, let s: Buffer, let n: Int);
	func test ();
	func sigmoid ( let y y: Buffer, let x: Buffer, let c: Buffer, let sigma: Float, let n: Int )
	func newBuffer( let data data: NSData ) -> Buffer
	func newBuffer( let length length: Int ) -> Buffer
}
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
	
	func gemv ( let y y: Buffer, let beta: Float, let a: Buffer, let x: Buffer, let alpha: Float, let n: Int, let m: Int, let trans: Bool ) {
		async {
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
	}
	func normal ( let y y: Buffer, let u: Buffer, let s: Buffer, let n: Int) {
		async {
			let W: [UInt16] = [UInt16](count: n, repeatedValue: 0)
			let N: [Float] = [Float](count: n, repeatedValue: 0)

			arc4random_buf(UnsafeMutablePointer<Void>(W), sizeof(UInt16)*W.count)
			vDSP_vfltu16(W, 1, UnsafeMutablePointer<Float>(N), 1, vDSP_Length(n))
		
			vDSP_vsadd(UnsafeMutablePointer<Float>(N).advancedBy(0/2), 1, [Float(1.0)], UnsafeMutablePointer<Float>(N), 1, vDSP_Length(n/2))
			vDSP_vsmul(UnsafeMutablePointer<Float>(N).advancedBy(n/2), 1, [Float(2.0)], UnsafeMutablePointer<Float>(N).advancedBy(n/2), 1, vDSP_Length(n/2))
			vDSP_vsmul(UnsafeMutablePointer<Float>(N).advancedBy(0/2), 1, [Float(1/65536.0)], UnsafeMutablePointer<Float>(N).advancedBy(0/2), 1, vDSP_Length(n))

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
	}
	func sigmoid ( let y y: Buffer, let x: Buffer, let c: Buffer, let sigma: Float, let n: Int ) {
		(0..<n/4).forEach {
			y.vector [ $0 ] = 0.5 * vtanhf ( sigma * ( x.vector [ $0 ] + c.vector [ $0 ] ) ) + float4 ( 0.5 )
		}
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

public class mtlComputer: cpuComputer {

	public enum Error: ErrorType {
		case DeviceNotFound
		case LibraryNotAvailable
		case PipelineNotAvailable(function: String)
	}

	let device: MTLDevice
	let queue: MTLCommandQueue
	let gemv: MTLComputePipelineState
	let sigmoid: MTLComputePipelineState
	let eval: MTLComputePipelineState
	let normal: MTLComputePipelineState
	
	public init ( let device: MTLDevice ) throws {
		
		guard let path: String = Config.bundle.pathForResource(Config.metal.name, ofType: Config.metal.ext) else {
			throw Error.LibraryNotAvailable
		}
		let library: MTLLibrary = try device.newLibraryWithFile(path)
		var pipelines: [String: MTLComputePipelineState] = [:]
		try library.functionNames.forEach {
			if let function: MTLFunction = library.newFunctionWithName($0), pipeline: MTLComputePipelineState = try device.newComputePipelineStateWithFunction(function) {
				pipelines [ $0 ] = pipeline
			}
		}
		guard let gemv: MTLComputePipelineState = pipelines["gemv"] else {
			throw Error.PipelineNotAvailable(function: "gemv")
		}
		guard let normal: MTLComputePipelineState = pipelines["normal"] else {
			throw Error.PipelineNotAvailable(function: "normal")
		}
		guard let sigmoid: MTLComputePipelineState = pipelines["lucky"] else {
			throw Error.PipelineNotAvailable(function: "lucky")
		}
		guard let eval: MTLComputePipelineState = pipelines["eval"] else {
			throw Error.PipelineNotAvailable(function: "eval")
		}
		self.gemv = gemv
		self.sigmoid = sigmoid
		self.eval = eval
		self.normal = normal
		self.device = device
		self.queue = device.newCommandQueue()
	}
	override func gemv ( let y y: Buffer, let beta: Float, let a: Buffer, let x: Buffer, let alpha: Float, let n: Int, let m: Int, let trans: Bool ) {
		if	let x: mtlBuffer = x as? mtlBuffer where x.mtl.device === device,
			let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let a: mtlBuffer = a as? mtlBuffer where a.mtl.device === device {
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(gemv)
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
			super.gemv(y: y, beta: beta, a: a, x: x, alpha: alpha, n: n, m: m, trans: trans)
		}
	}
	override func normal ( let y y: Buffer, let u: Buffer, let s: Buffer, let n: Int) {
		if	let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let u: mtlBuffer = u as? mtlBuffer where u.mtl.device === device,
			let s: mtlBuffer = s as? mtlBuffer where s.mtl.device === device,
			let w: mtlBuffer = newBuffer(length: sizeof(UInt16)*n) as? mtlBuffer {
			
			arc4random_buf(UnsafeMutablePointer(w.raw.bytes), w.raw.length)
			
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(normal)
			encoder.setBuffer(y.mtl, offset: 0, atIndex: 0)
			encoder.setBuffer(u.mtl, offset: 0, atIndex: 1)
			encoder.setBuffer(s.mtl, offset: 0, atIndex: 2)
			encoder.setBuffer(w.mtl, offset: 0, atIndex: 3)
			encoder.dispatchThreadgroups(MTLSize(width: n/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
			encoder.endEncoding()
			command.addCompletedHandler {(_)in
				w.mtl.setPurgeableState(.Empty)
			}
			command.commit()
		} else {
			super.normal(y: y, u: u, s: s, n: n)
		}
	}
	override func sigmoid( let y y: Buffer, let x: Buffer, let c: Buffer, let sigma: Float, let n: Int) {
		if	let x: mtlBuffer = x as? mtlBuffer where x.mtl.device === device,
			let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let c: mtlBuffer = c as? mtlBuffer where c.mtl.device === device {
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(sigmoid)
			encoder.setBuffer(y.mtl, offset: 0, atIndex: 0)
			encoder.setBuffer(x.mtl, offset: 0, atIndex: 1)
			encoder.setBuffer(c.mtl, offset: 0, atIndex: 2)
			encoder.setBytes([sigma], length: sizeof(Float), atIndex: 3)
			encoder.dispatchThreadgroups(MTLSize(width: n/16, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 4, height: 1, depth: 1))
			encoder.endEncoding()
			command.commit()
		} else {
			async {
			//	super.sigmoid(y: y, x: x, c: c, n: n)
			}
			fatalError("error")
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
		let n = 1 << 18
		let y = newBuffer(length: sizeof(Float)*n)
		let u = newBuffer(length: sizeof(Float)*n)
		let s = newBuffer(length: sizeof(Float)*n)
		for k in 0..<n {
			u.scalar[k] = 100
			s.scalar[k] = 500
		}
		normal(y: y, u: u, s: s, n: n)
		join()
		var mu = Float(0.0)
		var sigma = Float(0.0)
		for k in 0..<n {
			mu = mu + y.scalar[k]
		}
		mu = mu / Float(n)
		for k in 0..<n {
			sigma = sigma + (y.scalar[k]-mu)*(y.scalar[k]-mu)
		}
		sigma = sigma / Float(n)
		print("mu", mu, "sigma", sqrt(sigma))
	}
}