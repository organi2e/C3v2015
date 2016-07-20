//
//  Unit.swift
//  C³
//
//  Created by Kota Nakano on 7/20/16.
//
//
import Accelerate
import Metal
public class Unit {
	
	private let device: MTLDevice
	private let queue: MTLCommandQueue
	private let pipelines: Pipelines
	
	private struct Pipelines {
		let pdf: MTLComputePipelineState
		let cdf: MTLComputePipelineState
		let sigmoid: MTLComputePipelineState
		let normal: MTLComputePipelineState
	}
	
	public enum Error: ErrorType {
		case LibraryNotAvailable
		case PipelineNotAvailable(function: String)
	}
	
	init ( let device: MTLDevice ) throws {
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
		self.pipelines = Pipelines(
			pdf: try pipeline("pdf"),
			cdf: try pipeline("cdf"),
			sigmoid: try pipeline("sigmoid"),
			normal: try pipeline("normal")
		)
		self.device = device
		self.queue = device.newCommandQueue()
	}
	func step ( let x: la_object_t ) {
		
	}
	func pdf ( let x x: la_object_t, let mu: la_object_t, let sigma stddev: la_object_t, let group: dispatch_group_t? = nil ) -> la_object_t {
		
		let lambda: la_object_t = la_difference(x, mu)
		let rows: la_count_t = max(la_matrix_rows(lambda), la_matrix_rows(stddev))
		let cols: la_count_t = max(la_matrix_cols(lambda), la_matrix_cols(stddev))
		let length: Int = Int(rows*cols)
		
		let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*length))
		
		let command: MTLCommandBuffer = queue.commandBuffer()
		let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
		
		let ybuf: MTLBuffer = device.newBufferWithLength(sizeof(Float)*length, options: .CPUCacheModeDefaultCache)
		let xbuf: MTLBuffer = device.newBufferWithLength(sizeof(Float)*length, options: .CPUCacheModeDefaultCache)
		let sbuf: MTLBuffer = device.newBufferWithLength(sizeof(Float)*length, options: .CPUCacheModeDefaultCache)
		
		let gather: dispatch_semaphore_t = dispatch_semaphore_create(0)
		Unit.async {
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(xbuf.contents()), cols, rows == la_matrix_rows(lambda) && cols == la_matrix_cols(lambda) ? lambda : la_matrix_from_splat(lambda, rows, cols))
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(sbuf.contents()), cols, rows == la_matrix_rows(stddev) && cols == la_matrix_cols(stddev) ? stddev : la_matrix_from_splat(stddev, rows, cols))
			dispatch_semaphore_signal(gather)
		}
		encoder.setComputePipelineState(pipelines.pdf)
		encoder.setBuffer(ybuf, offset: 0, atIndex: 0)
		encoder.setBuffer(xbuf, offset: 0, atIndex: 1)
		encoder.setBuffer(sbuf, offset: 0, atIndex: 2)
		encoder.setBytes([Float(0.5*M_2_SQRTPI*M_SQRT1_2)], length: sizeof(Float), atIndex: 4)
		encoder.dispatchThreadgroups(MTLSize(width: length/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		encoder.endEncoding()
		command.addScheduledHandler {(_)in
			dispatch_semaphore_wait(gather, DISPATCH_TIME_FOREVER)
		}
		command.addCompletedHandler {(_)in
			memcpy(cache, ybuf.contents(), ybuf.length)
			group?.leave()
			Unit.leave()
			ybuf.setPurgeableState(.Empty)
			xbuf.setPurgeableState(.Empty)
			sbuf.setPurgeableState(.Empty)
		}
		Unit.enter()
		group?.enter()
		command.commit()
		return la_matrix_from_float_buffer_nocopy(cache, la_count_t(rows), la_count_t(cols), la_count_t(cols), Unit.hint, {free($0)}, Unit.attr)
	}
	func cdf ( let x: la_object_t, let group: dispatch_group_t? = nil ) -> la_object_t {
		group?.enter()
		group?.leave()
		return x
	}
	func sigmoid ( let x: la_object_t, let group: dispatch_group_t? = nil ) -> la_object_t {
		
		let rows: Int = Int(la_matrix_rows(x))
		let cols: Int = Int(la_matrix_cols(x))
		let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*rows*cols))
		
		let xbuf: MTLBuffer = device.newBufferWithLength(sizeof(Float)*rows*cols, options: .CPUCacheModeDefaultCache)
		let ybuf: MTLBuffer = device.newBufferWithLength(sizeof(Float)*rows*cols, options: .CPUCacheModeDefaultCache)
		
		let gather: dispatch_semaphore_t = dispatch_semaphore_create(0)
		
		Unit.async {
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(xbuf.contents()), la_count_t(cols), x)
			dispatch_semaphore_signal(gather)
		}
		let command: MTLCommandBuffer = queue.commandBuffer()
		let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
		encoder.setComputePipelineState(pipelines.sigmoid)
		encoder.setBuffer(ybuf, offset: 0, atIndex: 0)
		encoder.setBuffer(xbuf, offset: 0, atIndex: 1)
		encoder.dispatchThreadgroups(MTLSize(width: rows*cols/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		encoder.endEncoding()
		command.addScheduledHandler {(_)in
			dispatch_semaphore_wait(gather, DISPATCH_TIME_FOREVER)
		}
		command.addCompletedHandler {(_)in
			memcpy(cache, ybuf.contents(), ybuf.length)
			group?.leave()
			Unit.leave()
			ybuf.setPurgeableState(.Empty)
			xbuf.setPurgeableState(.Empty)
		}
		Unit.enter()
		group?.enter()
		command.commit()
		return la_matrix_from_float_buffer_nocopy(cache, la_count_t(rows), la_count_t(cols), la_count_t(cols), Unit.hint, {free($0)}, Unit.attr)
	}
	func normal ( let mu mu: la_object_t, let sigma: la_object_t, let group: dispatch_group_t? = nil ) -> la_object_t {
		
		assert(la_matrix_rows(mu)==la_matrix_rows(sigma))
		assert(la_matrix_cols(mu)==la_matrix_cols(sigma))
		
		let rows: Int = Int(la_matrix_rows(mu))
		let cols: Int = Int(la_matrix_cols(mu))
		let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*rows*cols))
		
		group?.enter()
		Unit.async {
			let N: vDSP_Length = vDSP_Length(rows*cols)
			let H: vDSP_Length = vDSP_Length(N/2)
			let W: [UInt8] = [UInt8](count: rows*cols, repeatedValue: 0)
			let C: [Float] = [Float](count: rows*cols, repeatedValue: 0)
			let L: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(C).advancedBy(Int(0))
			let R: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(C).advancedBy(Int(H))
			let P: UnsafeMutablePointer<Float> = cache.advancedBy(Int(0))
			let Q: UnsafeMutablePointer<Float> = cache.advancedBy(Int(H))
			
			arc4random_buf(UnsafeMutablePointer<Void>(W), sizeof(UInt8)*W.count)
			vDSP_vfltu8(W, 1, L, 1, N)
		
			vDSP_vsadd(L, 1, [Float(1.0)], L, 1, H)
			vDSP_vsdiv(L, 1, [Float(UInt8.max)+1.0], L, 1, N)
			
			vvlogf(L, L, [Int32(H)])
			vDSP_vsmul(L, 1, [Float(-2.0)], L, 1, H)
			vvsqrtf(L, L, [Int32(H)])

			vDSP_vsmul(R, 1, [Float(2.0*M_PI)], R, 1, H)
			vvsincosf(P, Q, R, [Int32(H)])

			vDSP_vmul(P, 1, L, 1, P, 1, H)
			vDSP_vmul(Q, 1, L, 1, Q, 1, H)
			group?.leave()
		}
		/*
		let result: MTLBuffer = device.newBufferWithLength(sizeof(Float)*rows*cols, options: .CPUCacheModeDefaultCache)
		let random: MTLBuffer = device.newBufferWithLength(sizeof(UInt8)*rows*cols, options: .CPUCacheModeDefaultCache)
		
		let command: MTLCommandBuffer = queue.commandBuffer()
		let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
		
		let gather: dispatch_semaphore_t = dispatch_semaphore_create(0)
		//Unit.async {
		arc4random_buf(random.contents(), random.length)
		dispatch_semaphore_signal(gather)
		//}
		
		encoder.setComputePipelineState(pipelines.normal)
		encoder.setBuffer(result, offset: 0, atIndex: 0)
		encoder.setBuffer(random, offset: 0, atIndex: 1)
		encoder.dispatchThreadgroups(MTLSize(width: rows*cols/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		encoder.endEncoding()
		command.addCompletedHandler {(_)in
			memcpy(cache, result.contents(), sizeof(Float)*rows*cols)
			random.setPurgeableState(.Empty)
			result.setPurgeableState(.Empty)
		}
		command.commit()
		*/
		return la_sum(mu, la_elementwise_product(sigma, la_matrix_from_float_buffer_nocopy(cache, la_count_t(rows), la_count_t(cols), la_count_t(cols), Unit.hint, {free($0)}, Unit.attr)))
	}
	func join() {
		dispatch_group_wait(Unit.dispatch.group, DISPATCH_TIME_FOREVER)
		/*
		let command: MTLCommandBuffer = queue.commandBuffer()
		command.addCompletedHandler {(_)in
		
		}
		command.commit()
		command.waitUntilCompleted()
		*/
	}
}
extension Unit {
	private static let dispatch: (queue: dispatch_queue_t, group: dispatch_group_t, semaphore: dispatch_semaphore_t) = (
		queue: dispatch_queue_create("\(Config.identifier).\(NSStringFromClass(Unit.self)).parallel", DISPATCH_QUEUE_CONCURRENT),
		group: dispatch_group_create(),
		semaphore: dispatch_semaphore_create(1)
	)
	static func async ( let task: Void -> Void ) {
		dispatch_group_async(dispatch.group, dispatch.queue, task)
	}
	static func sync ( let task: Void -> Void ) {
		dispatch_sync(dispatch.queue, task)
	}
	static func enter ( ) {
		dispatch.group.enter()
	}
	static func leave () {
		dispatch.group.leave()
	}
	class var hint: la_hint_t {
		return la_hint_t(LA_NO_HINT)
	}
	class var attr: la_attribute_t {
		return la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)
	}
}
extension dispatch_group_t {
	func leave() {
		dispatch_group_leave(self)
	}
	func enter() {
		dispatch_group_enter(self)
	}
}