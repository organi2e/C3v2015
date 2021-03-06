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

	private let queue: MTLCommandQueue
	private let group: dispatch_group_t
	private let pipelines: Pipelines
	
	private struct Pipelines {
		let exp: MTLComputePipelineState
		let step: MTLComputePipelineState
		let sign: MTLComputePipelineState
		let pdf: MTLComputePipelineState
		let cdf: MTLComputePipelineState
		let sigmoid: MTLComputePipelineState
		let normal: MTLComputePipelineState
	}
	
	public enum Error: ErrorType {
		case LibraryNotAvailable
		case PipelineNotAvailable(function: String)
	}
	
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
		pipelines = Pipelines(
			exp: try pipeline("exp"),
			step: try pipeline("step"),
			sign: try pipeline("sign"),
			pdf: try pipeline("pdf"),
			cdf: try pipeline("cdf"),
			sigmoid: try pipeline("sigmoid"),
			normal: try pipeline("normal")
		)
		group = dispatch_group_create()
		queue = device.newCommandQueue()
	}
	private func apply(let event: dispatch_group_t?, let task: ()->()) {
		event?.enter()
		dispatch_group_async(group, Unit.dispatch.queue) {
			task()
			event?.leave()
		}
	}
	private func bindWithOneArg ( let pipeline: MTLComputePipelineState, let x: la_object_t,let waits: [dispatch_group_t], let event: dispatch_group_t? ) -> la_object_t {
		let rows: UInt = x.rows
		let cols: UInt = x.cols
		
		let count: Int = x.count
		let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(count)
		
		self.enter()
		event?.enter()
		
		async {
			let command: MTLCommandBuffer = self.queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			
			let ybuf: MTLBuffer = command.device.newBufferWithLength(sizeof(Float)*count, options: .CPUCacheModeDefaultCache)
			let xbuf: MTLBuffer = command.device.newBufferWithLength(sizeof(Float)*count, options: .CPUCacheModeDefaultCache)
			
			waits.forEach { $0.wait() }
			
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(xbuf.contents()), la_count_t(cols), x)
			
			encoder.setComputePipelineState(pipeline)
			encoder.setBuffer(ybuf, offset: 0, atIndex: 0)
			encoder.setBuffer(xbuf, offset: 0, atIndex: 1)
			encoder.dispatchThreadgroups(MTLSize(width: count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
			encoder.endEncoding()
			command.addCompletedHandler {(_)in
				memcpy(cache, ybuf.contents(), ybuf.length)
				event?.leave()
				xbuf.setPurgeableState(.Empty)
				ybuf.setPurgeableState(.Empty)
				self.leave()
			}
			command.commit()
		}
		
		return la_matrix_from_float_buffer_nocopy(cache, la_count_t(rows), la_count_t(cols), la_count_t(cols), Unit.hint, { $0.destroy() }, Unit.attr)
	
	}
	public func sign ( let x: la_object_t, let waits: [dispatch_group_t] = [], let event: dispatch_group_t? = nil ) -> la_object_t {
		let count: Int = x.count
		let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(count)
		event?.enter()
		async {
			waits.forEach { $0.wait() }
			la_matrix_to_float_buffer(cache, x.cols, x)
			(0..<count).forEach {
				cache.advancedBy($0).memory = 0 < cache.advancedBy($0).memory ? 1 : 0 > cache.advancedBy($0).memory ? -1 : 0
			}
			event?.leave()
		}
		return la_matrix_from_float_buffer_nocopy(cache, x.rows, x.cols, x.cols, la_hint_t(LA_NO_HINT), { $0.destroy() }, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
//		return bindWithOneArg(pipelines.sign, x: x, waits: waits, event: event)
	}
	public func exp ( let x: la_object_t, let waits: [dispatch_group_t] = [], let event: dispatch_group_t? = nil ) -> la_object_t {
		let count: Int = x.count
		let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(count)
		event?.enter()
		async {
			waits.forEach { $0.wait() }
			la_matrix_to_float_buffer(cache, x.cols, x)
			(0..<count).forEach {
				cache.advancedBy($0).memory = 0 < cache.advancedBy($0).memory ? 1 : 0 > cache.advancedBy($0).memory ? -1 : 0
			}
			event?.leave()
		}
		return la_matrix_from_float_buffer_nocopy(cache, x.rows, x.cols, x.cols, la_hint_t(LA_NO_HINT), { $0.destroy() }, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
		//return bindWithOneArg(pipelines.exp, x: x, waits: waits, event: event)
	}
	public func sqrt( let x: la_object_t, let waits: [dispatch_group_t] = [], let event: dispatch_group_t? = nil ) -> la_object_t {
		
		assert(x.count != 0)
		
		let count: Int = x.count
		let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(count)
		apply(event) {
			waits.forEach { $0.wait() }
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), x.cols, x)
			vvsqrtf(cache, cache, [Int32(x.count)])
		}
		return la_matrix_from_float_buffer_nocopy(cache, x.rows, x.cols, x.cols, la_hint_t(LA_NO_HINT), { $0.destroy() }, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
		//return bindWithOneArg(pipelines.exp, x: x, waits: waits, event: event)
	}
	public func step ( let x: la_object_t, let waits: [dispatch_group_t] = [], let event: dispatch_group_t? = nil ) -> la_object_t {
		let count: Int = x.count
		let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(count)
		event?.enter()
		async {
			waits.forEach { $0.wait() }
			la_matrix_to_float_buffer(cache, x.cols, x)
			(0..<count).forEach {
				cache.advancedBy($0).memory = 0 < cache.advancedBy($0).memory ? 1 : 0
			}
			event?.leave()
		}
		return la_matrix_from_float_buffer_nocopy(cache, x.rows, x.cols, x.cols, Unit.hint, { $0.destroy() }, Unit.attr)
		//return bindWithOneArg(pipelines.step, x: x, waits: waits, event: event)
	}
	public func sigmoid ( let x: la_object_t, let waits: [dispatch_group_t] = [], let event: dispatch_group_t? = nil ) -> la_object_t {
		let cache: [Float] = [Float](count: x.count, repeatedValue: 0)
		waits.forEach { $0.wait() }
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), x.cols, x)
		vvtanhf(UnsafeMutablePointer<Float>(cache), cache, [Int32(x.count)])
		vDSP_vsmsa(UnsafePointer<Float>(cache), 1, [Float(0.5)], [Float(0.5)], UnsafeMutablePointer<Float>(cache), 1, vDSP_Length(x.count))
		return la_matrix_from_float_buffer(cache, x.rows, x.cols, x.cols, la_hint_t(LA_NO_HINT), la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING))
		//return bindWithOneArg(pipelines.sigmoid, x: x, waits: waits, event: event)
	}
	public func pdf ( let x x: la_object_t, let mu u: la_object_t, let sigma s: la_object_t, let waits: [dispatch_group_t] = [], let event: dispatch_group_t? = nil ) -> la_object_t {
		
		let rows: UInt = max(x.rows, u.rows, s.rows)
		let cols: UInt = max(x.cols, u.cols, s.cols)
		
		assert((x.rows==0&&x.cols==0)||(x.rows==rows&&x.cols==cols))
		assert((u.rows==0&&u.cols==0)||(u.rows==rows&&u.cols==cols))
		assert((s.rows==0&&s.cols==0)||(s.rows==rows&&s.cols==cols))
		
		let X: la_object_t = x.count == 0 ? la_matrix_from_splat(x, rows, cols) : x
		let U: la_object_t = u.count == 0 ? la_matrix_from_splat(u, rows, cols) : u
		let S: la_object_t = s.count == 0 ? la_matrix_from_splat(s, rows, cols) : s
		
		let count: Int = Int(rows*cols)
		let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(count)

		apply(event) {
			let level: [Float] = [Float](count: count, repeatedValue: 0)
			let sigma: [Float] = [Float](count: count, repeatedValue: 0)
			
			waits.forEach { $0.wait() }
			
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(level), cols, la_difference(X, U))
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(sigma), cols, S)
			
			vDSP_vdiv(sigma, 1, level, 1, cache, 1, vDSP_Length(count))
			
			vDSP_vsq(cache, 1, cache, 1, vDSP_Length(count))
			vDSP_vsmul(cache, 1, [Float(-0.5)], cache, 1, vDSP_Length(count))
			
			vvexpf(cache, cache, [Int32(count)])
			
			vDSP_vdiv(sigma, 1, cache, 1, cache, 1, vDSP_Length(count))
			vDSP_vsmul(cache, 1, [Float(0.5*M_2_SQRTPI*M_SQRT1_2)], cache, 1, vDSP_Length(count))
			
		}
		return la_matrix_from_float_buffer_nocopy(cache, la_count_t(rows), la_count_t(cols), la_count_t(cols), Unit.hint, { $0.destroy() }, Unit.attr)
		
/*
		self.enter()
		group?.enter()

		async {
			let command: MTLCommandBuffer = self.queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			
			let ybuf: MTLBuffer = command.device.newBufferWithLength(sizeof(Float)*count, options: .CPUCacheModeDefaultCache)
			let xbuf: MTLBuffer = command.device.newBufferWithLength(sizeof(Float)*count, options: .CPUCacheModeDefaultCache)
			let sbuf: MTLBuffer = command.device.newBufferWithLength(sizeof(Float)*count, options: .CPUCacheModeDefaultCache)
			
			waits.forEach { $0.wait() }
			
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(xbuf.contents()), cols, rows == level.rows && cols == level.cols ? level : la_matrix_from_splat(level, la_count_t(rows), la_count_t(cols)))
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(sbuf.contents()), cols, rows == sigma.rows && cols == sigma.cols ? sigma : la_matrix_from_splat(sigma, la_count_t(rows), la_count_t(cols)))

			encoder.setComputePipelineState(self.pipelines.pdf)
			encoder.setBuffer(ybuf, offset: 0, atIndex: 0)
			encoder.setBuffer(xbuf, offset: 0, atIndex: 1)
			encoder.setBuffer(sbuf, offset: 0, atIndex: 2)
			encoder.setBytes([Float(0.5*M_2_SQRTPI*M_SQRT1_2)], length: sizeof(Float), atIndex: 3)
			encoder.dispatchThreadgroups(MTLSize(width: count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
			encoder.endEncoding()

			command.addCompletedHandler {(_)in
				memcpy(cache, ybuf.contents(), ybuf.length)
				group?.leave()
				sbuf.setPurgeableState(.Empty)
				xbuf.setPurgeableState(.Empty)
				ybuf.setPurgeableState(.Empty)
				self.leave()
			}
			command.commit()
		}
*/
	}
	public func cdf ( let x x: la_object_t, let mu u: la_object_t, let sigma s: la_object_t, let waits: [dispatch_group_t] = [], let group: dispatch_group_t? = nil ) -> la_object_t {
		
		let level: la_object_t = la_difference(x, u)
		let sigma: la_object_t = s
		
		let rows: UInt = level.count < sigma.count ? sigma.rows : level.rows
		let cols: UInt = level.count < sigma.count ? sigma.cols : level.cols
		
		let count: Int = level.count < sigma.count ? sigma.count : level.count
		let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*count))
		
		self.enter()
		group?.enter()
		
		async {
			let command: MTLCommandBuffer = self.queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()

			let ybuf: MTLBuffer = command.device.newBufferWithLength(sizeof(Float)*count, options: .CPUCacheModeDefaultCache)
			let xbuf: MTLBuffer = command.device.newBufferWithLength(sizeof(Float)*count, options: .CPUCacheModeDefaultCache)
			let sbuf: MTLBuffer = command.device.newBufferWithLength(sizeof(Float)*count, options: .CPUCacheModeDefaultCache)
			
			waits.forEach { $0.wait() }
			
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(xbuf.contents()), la_count_t(cols), rows == level.rows && cols == level.cols ? level : la_matrix_from_splat(level, la_count_t(rows), la_count_t(cols)))
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(sbuf.contents()), la_count_t(cols), rows == sigma.rows && cols == sigma.cols ? sigma : la_matrix_from_splat(sigma, la_count_t(rows), la_count_t(cols)))

			encoder.setComputePipelineState(self.pipelines.cdf)
			encoder.setBuffer(ybuf, offset: 0, atIndex: 0)
			encoder.setBuffer(xbuf, offset: 0, atIndex: 1)
			encoder.setBuffer(sbuf, offset: 0, atIndex: 2)
			encoder.setBytes([Float(M_SQRT1_2)], length: sizeof(Float), atIndex: 3)
			encoder.dispatchThreadgroups(MTLSize(width: count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
			encoder.endEncoding()

			command.addCompletedHandler {(_)in
				memcpy(cache, ybuf.contents(), ybuf.length)
				group?.leave()
				sbuf.setPurgeableState(.Empty)
				xbuf.setPurgeableState(.Empty)
				ybuf.setPurgeableState(.Empty)
				self.leave()
			}
			command.commit()
		}
		return la_matrix_from_float_buffer_nocopy(cache, la_count_t(rows), la_count_t(cols), la_count_t(cols), Unit.hint, {free($0)}, Unit.attr)
	}
	public func normal ( let rows rows: UInt, let cols: UInt, let event: dispatch_group_t? = nil ) -> la_object_t {

		let count: Int = Int(rows * cols)
		let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(count)
		///*
		apply(event) {
			typealias Type = UInt16
			
			let N: vDSP_Length = vDSP_Length(count)
			let H: vDSP_Length = vDSP_Length(N/2)
			let W: [Type] = [Type](count: count, repeatedValue: 0)
			let C: [Float] = [Float](count: count, repeatedValue: 0)
			let L: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(C).advancedBy(Int(0))
			let R: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(C).advancedBy(Int(H))
			let P: UnsafeMutablePointer<Float> = cache.advancedBy(Int(0))
			let Q: UnsafeMutablePointer<Float> = cache.advancedBy(Int(H))
			
			arc4random_buf(UnsafeMutablePointer<Void>(W), sizeof(Type)*W.count)
			
			switch sizeof(Type) {
			case 1:
				vDSP_vfltu8(UnsafePointer<UInt8>(W), 1, UnsafeMutablePointer<Float>(C), 1, vDSP_Length(count))
				break
			case 2:
				vDSP_vfltu16(UnsafePointer<UInt16>(W), 1, UnsafeMutablePointer<Float>(C), 1, vDSP_Length(count))
				break
			case 4:
				vDSP_vfltu32(UnsafePointer<UInt32>(W), 1, UnsafeMutablePointer<Float>(C), 1, vDSP_Length(count))
				break
			default:
				break
			}
			
			vDSP_vsadd(L, 1, [Float(1.0)], L, 1, H)
			vDSP_vsdiv(L, 1, [Float(Type.max)+1.0], L, 1, N)
			
			vvlogf(L, L, [Int32(H)])
			vDSP_vsmul(L, 1, [Float(-2.0)], L, 1, H)
			vvsqrtf(L, L, [Int32(H)])

			vDSP_vsmul(R, 1, [Float(2.0*M_PI)], R, 1, H)
			vvsincosf(P, Q, R, [Int32(H)])

			vDSP_vmul(P, 1, L, 1, P, 1, H)
			vDSP_vmul(Q, 1, L, 1, Q, 1, H)

		}
		//*/
		/*
		self.enter()
		event?.enter()
		async {
			let command: MTLCommandBuffer = self.queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			let result: MTLBuffer = command.device.newBufferWithLength(sizeof(Float)*count, options: .CPUCacheModeDefaultCache)
			let random: MTLBuffer = command.device.newBufferWithLength(sizeof(UInt8)*count, options: .CPUCacheModeDefaultCache)
			
			arc4random_buf(random.contents(), random.length)
			
			encoder.setComputePipelineState(self.pipelines.normal)
			encoder.setBuffer(result, offset: 0, atIndex: 0)
			encoder.setBuffer(random, offset: 0, atIndex: 1)
			encoder.dispatchThreadgroups(MTLSize(width: count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
			encoder.endEncoding()
			
			command.addCompletedHandler {(_)in
				memcpy(cache, result.contents(), sizeof(Float)*count)
				event?.leave()
				random.setPurgeableState(.Empty)
				result.setPurgeableState(.Empty)
				self.leave()
			}
			command.commit()
		}
		*/
		return la_matrix_from_float_buffer_nocopy(cache, la_count_t(rows), la_count_t(cols), la_count_t(cols), Unit.hint, { $0.destroy() }, Unit.attr)
	}
	public func div(let y y: la_object_t, let x: la_object_t, let waits: [dispatch_group_t] = [], let event: dispatch_group_t? = nil) -> la_object_t {
		
		assert(( x.count != 0 && y.count != 0 && x.count == y.count ) || ( x.count == 0 && y.count != 0 ) || ( x.count != 0 && y.count == 0 ))
		
		let count: Int = max(x.count, y.count)
		let rows: UInt = ( x.count < y.count ? y : x ).rows
		let cols: UInt = ( x.count < y.count ? y : x ).cols
		let cache: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>.alloc(Int(count))
		
		apply(event) {
			
			let xbuf: [Float] = [Float](count: count, repeatedValue: 0)
			let ybuf: [Float] = [Float](count: count, repeatedValue: 0)
			
			waits.forEach { $0.wait() }
			
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(xbuf), x.cols, x)
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(ybuf), y.cols, y)
			
			vDSP_vdiv(xbuf, 1, ybuf, 1, cache, 1, vDSP_Length(count))
			
		}
		return la_matrix_from_float_buffer_nocopy(cache, rows, cols, cols, la_hint_t(LA_NO_HINT), { $0.destroy() }, la_attribute_t(LA_DEFAULT_ATTRIBUTES))
	}
	private func enter ( ) {
		group.enter()
	}
	private func leave () {
		group.leave()
	}
	private func async ( let task: () -> () ) {
		dispatch_group_async(group, Unit.dispatch.queue, task)
	}
	private func sync ( let task: () -> () ) {
		dispatch_sync(Unit.dispatch.queue, task)
	}
	public func join( let time: dispatch_time_t = DISPATCH_TIME_FOREVER ) {
		group.wait(time)
	}
}
extension Unit {
	private static let dispatch: (queue: dispatch_queue_t, __group: dispatch_group_t, semaphore: dispatch_semaphore_t) = (
		queue: dispatch_queue_create("\(Config.identifier).\(NSStringFromClass(Unit.self)).parallel", DISPATCH_QUEUE_CONCURRENT),
		__group: dispatch_group_create(),
		semaphore: dispatch_semaphore_create(1)
	)
	/*
	static func async ( let task: Void -> Void ) {
		dispatch_group_async(dispatch.__group, dispatch.__queue, task)
	}
	static func sync ( let task: Void -> Void ) {
		dispatch_sync(dispatch.__queue, task)
	}
	static func enter ( ) {
		dispatch.__group.enter()
	}
	static func leave () {
		dispatch.__group.leave()
	}
	*/
	class var hint: la_hint_t {
		return la_hint_t(LA_NO_HINT)
	}
	class var attr: la_attribute_t {
		return la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)
	}
}
internal extension dispatch_group_t {
	func leave() {
		dispatch_group_leave(self)
	}
	func enter() {
		dispatch_group_enter(self)
	}
	func wait ( let time: dispatch_time_t = DISPATCH_TIME_FOREVER ) {
		dispatch_group_wait(self, time)
	}
}
internal extension dispatch_semaphore_t {
	func signal ( ) {
		dispatch_semaphore_signal(self)
	}
	func wait ( let time: dispatch_time_t = DISPATCH_TIME_FOREVER ) {
		dispatch_semaphore_wait(self, time)
	}
}
internal extension la_object_t {
	var rows: UInt {
		return la_matrix_rows(self)
	}
	var cols: UInt {
		return la_matrix_cols(self)
	}
	var count: Int {
		return Int(rows * cols)
	}
}
func + ( let lhs: la_object_t, let rhs: la_object_t ) -> la_object_t {
	return la_sum(lhs, rhs)
}
func - ( let lhs: la_object_t, let rhs: la_object_t ) -> la_object_t {
	return la_difference(lhs, rhs)
}
func * ( let lhs: la_object_t, let rhs: la_object_t ) -> la_object_t {
	return la_elementwise_product(lhs, rhs)
}
