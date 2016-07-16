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
	
	func add ( let y: Buffer, let _: Buffer, let _: Buffer )
	func sub ( let y: Buffer, let _: Buffer, let _: Buffer )
	func mul ( let y: Buffer, let _: Buffer, let _: Buffer )
	func div ( let y: Buffer, let _: Buffer, let _: Buffer )
	
	func add ( let y: Buffer, let _: Buffer, let _: Float )
	func sub ( let y: Buffer, let _: Buffer, let _: Float )
	func mul ( let y: Buffer, let _: Buffer, let _: Float )
	func div ( let y: Buffer, let _: Buffer, let _: Float )
	
	func abs ( let y: Buffer, let _: Buffer )
	func neg ( let y: Buffer, let _: Buffer )
	func sq ( let y: Buffer, let _: Buffer )
	func sqrt ( let y: Buffer, let _: Buffer )
	
	func exp ( let y: Buffer, let _: Buffer )
	func log ( let y: Buffer, let _: Buffer )

	func fill( let y: Buffer, let _: Float)
	func clamp( let y: Buffer, let _: Buffer, let _: Float, let _: Float)
	
	func sum ( let x: Buffer ) -> Float
	func dot ( let a: Buffer, let _: Buffer ) -> Float
	func gemv ( let y y: Buffer, let beta: Float, let a: Buffer, let x: Buffer, let alpha: Float, let n: Int, let m: Int, let trans: Bool )
	
	func normal ( let y: Buffer, let u: Buffer, let s: Buffer )
	func pdf ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer )
	func cdf ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer )
	
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
				y.scalar[offset] = 0.5 * erfcf(y.scalar[offset])
			}
		}
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
				y.scalar[offset] = 0.5 * erfcf(y.scalar[offset])
			}
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

	struct Pipeline {
		let gemv: MTLComputePipelineState
		let normal: MTLComputePipelineState
		let pdf: MTLComputePipelineState
	};
	let pipeline: Pipeline
	let device: MTLDevice
	let queue: MTLCommandQueue
	let sigmoid: MTLComputePipelineState
	let eval: MTLComputePipelineState
	
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
		guard let pdf: MTLComputePipelineState = pipelines["pdf"] else {
			throw Error.PipelineNotAvailable(function: "pdf")
		}
		pipeline = Pipeline(gemv: gemv, normal: normal, pdf: pdf)
		self.sigmoid = sigmoid
		self.eval = eval
		self.device = device
		self.queue = device.newCommandQueue()
	}
	override func gemv ( let y y: Buffer, let beta: Float, let a: Buffer, let x: Buffer, let alpha: Float, let n: Int, let m: Int, let trans: Bool ) {
		if	let x: mtlBuffer = x as? mtlBuffer where x.mtl.device === device,
			let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let a: mtlBuffer = a as? mtlBuffer where a.mtl.device === device {
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(pipeline.gemv)
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
	override func normal ( let y: Buffer, let u: Buffer, let s: Buffer ) {
		assert(y.scalar.count==u.scalar.count)
		assert(y.scalar.count==s.scalar.count)
		if	let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let u: mtlBuffer = u as? mtlBuffer where u.mtl.device === device,
			let s: mtlBuffer = s as? mtlBuffer where s.mtl.device === device,
			let w: mtlBuffer = newBuffer(length: sizeof(UInt16)*y.scalar.count) as? mtlBuffer {
			
			arc4random_buf(UnsafeMutablePointer(w.raw.bytes), w.raw.length)
			
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(pipeline.normal)
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
		} else {
			async {
				super.normal(y, u: u, s: s)
			}
		}
	}
	override func pdf ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer ) {
		assert(y.scalar.count==x.scalar.count)
		assert(y.scalar.count==y.scalar.count)
		assert(y.scalar.count==s.scalar.count)
		if	let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let x: mtlBuffer = x as? mtlBuffer where x.mtl.device === device,
			let u: mtlBuffer = u as? mtlBuffer where u.mtl.device === device,
			let s: mtlBuffer = s as? mtlBuffer where s.mtl.device === device {
			
			let command: MTLCommandBuffer = queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(pipeline.normal)
			encoder.setBuffer(y.mtl, offset: 0, atIndex: 0)
			encoder.setBuffer(x.mtl, offset: 0, atIndex: 1)
			encoder.setBuffer(u.mtl, offset: 0, atIndex: 2)
			encoder.setBuffer(s.mtl, offset: 0, atIndex: 3)
			encoder.dispatchThreadgroups(MTLSize(width: y.scalar.count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
			encoder.endEncoding()
			command.commit()
		} else {
			async {
				super.pdf(y, x: x, u: u, s: s)
			}
		}
	}
	override func cdf ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer ) {
		assert(y.scalar.count==x.scalar.count)
		assert(y.scalar.count==y.scalar.count)
		assert(y.scalar.count==s.scalar.count)
		if	let y: mtlBuffer = y as? mtlBuffer where y.mtl.device === device,
			let x: mtlBuffer = x as? mtlBuffer where x.mtl.device === device,
			let u: mtlBuffer = u as? mtlBuffer where u.mtl.device === device,
			let s: mtlBuffer = s as? mtlBuffer where s.mtl.device === device {
		} else {
			async {
				super.cdf(y, x: x, u: u, s: s)
			}
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
		let n = 1 << 22
		let y = newBuffer(length: sizeof(Float)*n)
		let u = newBuffer(length: sizeof(Float)*n)
		let s = newBuffer(length: sizeof(Float)*n)
		for k in 0..<n {
			u.scalar[k] = 100
			s.scalar[k] = 500
		}
		normal(y, u: u, s: s)
		join()
		let mu: Float = y.scalar.reduce(0.0){$0+$1} / Float(n)
		let sigma: Float = y.scalar.map{($0-mu)*($0-mu)}.reduce(0){$0+$1} / Float(n)
		print("mu", mu, "sigma", sqrtf(sigma))
	}
}