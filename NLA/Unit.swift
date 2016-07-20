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
			sigmoid: try pipeline("sigmoid"),
			normal: try pipeline("normal")
		)
		self.device = device
		self.queue = device.newCommandQueue()
	}
	func step ( let x: la_object_t ) {
		
	}
	func sigmoid ( let x: la_object_t ) -> ( la_object_t, dispatch_semaphore_t ) {
		let rows: Int = Int(la_matrix_rows(x))
		let cols: Int = Int(la_matrix_cols(x))
		let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*rows*cols))
		
		let xbuf: MTLBuffer = device.newBufferWithLength(sizeof(Float)*rows*cols, options: .CPUCacheModeDefaultCache)
		let ybuf: MTLBuffer = device.newBufferWithLength(sizeof(Float)*rows*cols, options: .CPUCacheModeDefaultCache)
		
		let finish: dispatch_semaphore_t = dispatch_semaphore_create(0)
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
			dispatch_semaphore_signal(finish)
			ybuf.setPurgeableState(.Empty)
			xbuf.setPurgeableState(.Empty)
		}
		command.commit()
		return (
			la_sum(la_splat_from_float(0.5, Unit.attr), la_scale_with_float(la_matrix_from_float_buffer_nocopy(cache, la_count_t(rows), la_count_t(cols), la_count_t(cols), Unit.hint, {free($0)}, Unit.attr), 0.5)),
			finish
		)
	}
	func normal ( let rows: Int, let cols: Int ) -> ( la_object_t, dispatch_semaphore_t ) {
		let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*rows*cols))
		
		let result: MTLBuffer = device.newBufferWithLength(sizeof(Float)*rows*cols, options: .CPUCacheModeDefaultCache)
		let random: MTLBuffer = device.newBufferWithLength(sizeof(UInt8)*rows*cols, options: .CPUCacheModeDefaultCache)
		
		let finish: dispatch_semaphore_t = dispatch_semaphore_create(0)
		let gather: dispatch_semaphore_t = dispatch_semaphore_create(0)
		
		let command: MTLCommandBuffer = queue.commandBuffer()
		let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
		
		Unit.async {
			arc4random_buf(random.contents(), random.length)
			dispatch_semaphore_signal(gather)
		}
		encoder.setComputePipelineState(pipelines.normal)
		encoder.setBuffer(result, offset: 0, atIndex: 0)
		encoder.setBuffer(random, offset: 0, atIndex: 1)
		encoder.dispatchThreadgroups(MTLSize(width: rows*cols/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		encoder.endEncoding()
		command.addScheduledHandler {(_)in
			dispatch_semaphore_wait(gather, DISPATCH_TIME_FOREVER)
		}
		command.addCompletedHandler {(_)in
			memcpy(cache, result.contents(), sizeof(Float)*rows*cols)
			dispatch_semaphore_signal(finish)
			random.setPurgeableState(.Empty)
			result.setPurgeableState(.Empty)
		}
		command.commit()
		return (la_matrix_from_float_buffer_nocopy(cache, la_count_t(rows), la_count_t(cols), la_count_t(cols), Unit.hint, {free($0)}, Unit.attr), finish)
	}
	func join() {
		let command: MTLCommandBuffer = queue.commandBuffer()
		command.commit()
		command.waitUntilCompleted()
	}
}
extension Unit {
	static let dispatch: (queue: dispatch_queue_t, group: dispatch_group_t, semaphore: dispatch_semaphore_t) = (
		queue: dispatch_queue_create("\(Config.identifier).\(NSStringFromClass(Unit.self)).parallel", DISPATCH_QUEUE_CONCURRENT),
		group: dispatch_group_create(),
		semaphore: dispatch_semaphore_create(1)
	)
	static func async ( let task: Void -> Void ) {
		dispatch_async(dispatch.queue, task)
	}
	static func sync ( let task: Void -> Void ) {
		dispatch_sync(dispatch.queue, task)
	}
	class var hint: la_hint_t {
		return la_hint_t(LA_NO_HINT)
	}
	class var attr: la_attribute_t {
		return la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)
	}
}