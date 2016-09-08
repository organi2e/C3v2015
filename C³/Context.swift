//
//  Context.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//
import Accelerate
import CoreData
import Metal
import MetalKit

public class Context: NSManagedObjectContext {
	public var optimizerFactory: Int -> GradientOptimizer = SGD.factory()
	enum Error: String, ErrorType {
		case InvalidContext = "InvalidContext"
		enum CoreData: ErrorType, CustomStringConvertible {
			case NoModelFound
			case NoModelAvailable
			case InsertionFails(entity: NSManagedObject.Type)
			var description: String {
				return ""
			}
		}
		enum Metal: ErrorType, CustomStringConvertible {
			case NoDeviceFound
			case NoLibraryFound
			case LibraryNotAvailable
			case PipelineNotAvailable(function: String)
			var description: String {
				return ""
			}
		}
	}
	
	struct MTL {
		let device: MTLDevice
		let queue: MTLCommandQueue
		let functions: [String: MTLFunction]
		
		init(let device mtldevice: MTLDevice) throws {
			guard let libpath: String = NSBundle(forClass: Context.self).pathForResource("default", ofType: "metallib"), library: MTLLibrary = try? mtldevice.newLibraryWithFile(libpath) else {
				throw Error.Metal.NoLibraryFound
			}
			var myfunctions: [String: MTLFunction] = [:]
			try library.functionNames.forEach {
				guard let function: MTLFunction = library.newFunctionWithName($0) else {
					throw Error.Metal.PipelineNotAvailable(function: $0)
				}
				myfunctions[$0] = function
			}
			device = mtldevice
			queue = device.newCommandQueue()
			functions = myfunctions
		}
	}
	
	var computePipelineCache: [String: MTLComputePipelineState]
	var renderPipelineCache: [String: [MTLPixelFormat:MTLRenderPipelineState]]
	
	private let mtl: MTL
	private let storage: NSURL?
	
	public init( let storage storageurl: NSURL? = nil, let device: MTLDevice? = MTLCreateSystemDefaultDevice() ) throws {
		
		guard let device: MTLDevice = device else {
			throw Error.Metal.NoDeviceFound
		}
		
		mtl = try MTL(device: device)
		storage = storageurl
		computePipelineCache = [:]
		renderPipelineCache = [:]
		
		super.init(concurrencyType: .PrivateQueueConcurrencyType)
		
		guard let url: NSURL = Config.bundle.URLForResource(Config.coredata.name, withExtension: Config.coredata.ext) else {
			throw Error.CoreData.NoModelFound
		}
		guard let model: NSManagedObjectModel = NSManagedObjectModel(contentsOfURL: url) else {
			throw Error.CoreData.NoModelAvailable
		}
		let storecoordinator: NSPersistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
		let storetype: String = storage == nil ? NSInMemoryStoreType : storage?.pathExtension == "sqlite" ? NSSQLiteStoreType : NSBinaryStoreType
		try storecoordinator.addPersistentStoreWithType(storetype, configuration: nil, URL: storage, options: nil)
		
		persistentStoreCoordinator = storecoordinator
		
	}
	public override func encodeWithCoder(aCoder: NSCoder) {
		super.encodeWithCoder(aCoder)
		aCoder.encodeObject(storage, forKey: "storage")
	}
	required public init?(coder aDecoder: NSCoder) {
		storage = aDecoder.decodeObjectForKey("storage")as?NSURL
		guard let device: MTLDevice = MTLCreateSystemDefaultDevice(), newmtl: MTL = try?MTL(device: device) else {
			fatalError(Error.Metal.NoDeviceFound.description)
		}
		mtl = newmtl
		computePipelineCache = [:]
		renderPipelineCache = [:]
		super.init(coder: aDecoder)
		guard let url: NSURL = Config.bundle.URLForResource(Config.coredata.name, withExtension: Config.coredata.ext) else {
			fatalError(Error.CoreData.NoModelFound.description)
		}
		guard let model: NSManagedObjectModel = NSManagedObjectModel(contentsOfURL: url) else {
			fatalError(Error.CoreData.NoModelAvailable.description)
		}
		let storecoordinator: NSPersistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
		do {
			let storetype: String = storage == nil ? NSInMemoryStoreType : storage?.pathExtension == "sqlite" ? NSSQLiteStoreType : NSBinaryStoreType
			try storecoordinator.addPersistentStoreWithType(storetype, configuration: nil, URL: storage, options: nil)
			persistentStoreCoordinator = storecoordinator
		} catch let e {
			fatalError(String(e))
		}
	}
}
extension Context {
	public func newRenderLayer(let pixelFormat: MTLPixelFormat = .BGRA8Unorm) -> CAMetalLayer {
		let layer: CAMetalLayer = CAMetalLayer()
		layer.device = mtl.device
		layer.pixelFormat = pixelFormat
		return layer
	}
	public func newRenderCommand(let sync sync: Bool = false, let layer: CAMetalLayer, let shader: (String, String), let color: (Double, Double, Double, Double) = (0,0,0,0), let schedule: (()->())? = nil, let complete: (()->())? = nil, let configure: (MTLRenderCommandEncoder->())) -> Bool {
		let key: String = "\(shader.0),\(shader.1)"
		if renderPipelineCache.indexForKey(key) == nil {
			let descriptor: MTLRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
			if let vert: MTLFunction = mtl.functions[shader.0] {
				descriptor.vertexFunction = vert
			}
			if let frag: MTLFunction = mtl.functions[shader.1] {
				descriptor.fragmentFunction = frag
			}
			descriptor.colorAttachments[0].pixelFormat = layer.pixelFormat
			if let pipeline: MTLRenderPipelineState = try?mtl.device.newRenderPipelineStateWithDescriptor(descriptor) {
				if renderPipelineCache.indexForKey(key) == nil {
					renderPipelineCache.updateValue([:], forKey: key)
				}
				renderPipelineCache[key]?[layer.pixelFormat] = pipeline
			}
		}
		if let pipeline: MTLRenderPipelineState = renderPipelineCache[key]?[layer.pixelFormat], let drawable: CAMetalDrawable = layer.nextDrawable() {
			
			let descriptor: MTLRenderPassDescriptor = MTLRenderPassDescriptor()
			descriptor.colorAttachments[0].texture = drawable.texture
			descriptor.colorAttachments[0].clearColor = MTLClearColor(red: color.1, green: color.2, blue: color.3, alpha: color.0)
			descriptor.colorAttachments[0].loadAction = .Clear
			descriptor.colorAttachments[0].storeAction = .Store
			
			let command: MTLCommandBuffer = mtl.queue.commandBuffer()
			let encoder: MTLRenderCommandEncoder = command.renderCommandEncoderWithDescriptor(descriptor)
			
			if let schedule: () -> () = schedule {
				command.addScheduledHandler {(_)in
					schedule()
				}
			}
			
			if let complete: () -> () = complete {
				command.addCompletedHandler {(_)in
					complete()
				}
			}
			
			encoder.setRenderPipelineState(pipeline)
			configure(encoder)
			encoder.endEncoding()
			command.presentDrawable(drawable)
			command.commit()
			
		} else {
			return false
		}
		return true
	}
	internal func newCommand() -> Command {
		return mtl.queue.commandBuffer()
	}
	internal func newPipeline(name: String) throws -> Pipeline {
		guard let function: MTLFunction = mtl.functions[name] else {
			throw Context.Error.Metal.PipelineNotAvailable(function: name)
		}
		return try mtl.device.newComputePipelineStateWithFunction(function)
	}
	internal func newComputeCommand (sync sync: Bool = false, function name: String, grid: (Int, Int, Int), threads: (Int, Int, Int), schedule: (()->())? = nil, complete: (()->())? = nil, configure: MTLComputeCommandEncoder->()) -> Bool {
			if computePipelineCache.indexForKey(name) == nil {
				guard let function: MTLFunction = mtl.functions[name] else {
					assertionFailure(name)
					return false
				}
				if let pipeline: MTLComputePipelineState = try?mtl.device.newComputePipelineStateWithFunction(function) {
					computePipelineCache.updateValue(pipeline, forKey: name)
				}
			}
			if let pipeline: MTLComputePipelineState = computePipelineCache[name] {
				let command: MTLCommandBuffer = mtl.queue.commandBuffer()
				if let schedule: ()->() = schedule {
					command.addScheduledHandler {(_)in
						schedule()
					}
				}
				if let complete: ()->() = complete {
					command.addCompletedHandler {(_)in
						complete()
					}
				}
				let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
				encoder.setComputePipelineState(pipeline)
				configure(encoder)
				encoder.dispatchThreadgroups(MTLSize(width: grid.0, height: grid.1, depth: grid.2), threadsPerThreadgroup: MTLSize(width: threads.0, height: threads.1, depth: threads.2))
				encoder.endEncoding()
				command.commit()
				if sync { command.waitUntilCompleted() }
			} else {
				return false
			}
			return true	}
	internal func newComputeCommand ( let sync sync: Bool = false, let function name: String, let schedule: (()->())? = nil, let complete: (()->())? = nil, let configure: (MTLComputeCommandEncoder->())) -> Bool {
		if computePipelineCache.indexForKey(name) == nil {
			guard let function: MTLFunction = mtl.functions[name] else {
				assertionFailure(name)
				return false
			}
			if let pipeline: MTLComputePipelineState = try?mtl.device.newComputePipelineStateWithFunction(function) {
				computePipelineCache.updateValue(pipeline, forKey: name)
			}
		}
		if let pipeline: MTLComputePipelineState = computePipelineCache[name] {
			let command: MTLCommandBuffer = mtl.queue.commandBuffer()
			if let schedule: ()->() = schedule {
				command.addScheduledHandler {(_)in
					schedule()
				}
			}
			if let complete: ()->() = complete {
				command.addCompletedHandler {(_)in
					complete()
				}
			}
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(pipeline)
			configure(encoder)
			encoder.endEncoding()
			command.commit()
			if sync { command.waitUntilCompleted() }
		} else {
			return false
		}
		return true
	}
	internal func newBlitCommand( let sync sync: Bool = false, let schedule: (()->())? = nil, let complete: (()->())? = nil, let configure: (MTLBlitCommandEncoder->())) -> Bool {
		let command: MTLCommandBuffer = mtl.queue.commandBuffer()
		if let schedule: ()->() = schedule {
			command.addScheduledHandler {(_)in
				schedule()
			}
		}
		if let complete: ()->() = complete {
			command.addCompletedHandler {(_)in
				complete()
			}
		}
		let encoder: MTLBlitCommandEncoder = command.blitCommandEncoder()
		configure(encoder)
		encoder.endEncoding()
		command.commit()
		if sync { command.waitUntilCompleted() }
		return true
	}
	internal func newCommand(let sync sync: Bool = false, let schedule: (()->())? = nil, let complete: (()->())? = nil) {
		let command: MTLCommandBuffer = mtl.queue.commandBuffer()
		if let schedule: ()->() = schedule {
			command.addScheduledHandler {(_)in
				schedule()
			}
		}
		if let complete: ()->() = complete {
			command.addCompletedHandler {(_)in
				complete()
			}
		}
		command.commit()
		if sync { command.waitUntilCompleted() }
	}
	public func newSampler(label: String? = nil, filters: (MTLSamplerMinMagFilter, MTLSamplerMinMagFilter) = (.Nearest, .Nearest), addressing: (MTLSamplerAddressMode, MTLSamplerAddressMode) = (.Repeat, .Repeat)) -> MTLSamplerState {
		let descriptor: MTLSamplerDescriptor = MTLSamplerDescriptor()
		descriptor.minFilter = filters.0
		descriptor.magFilter = filters.1
		descriptor.sAddressMode = addressing.0
		descriptor.tAddressMode = addressing.1
		return mtl.device.newSamplerStateWithDescriptor(descriptor)
	}
	public func newTexture2D(let pixelFormat: MTLPixelFormat = .BGRA8Unorm, let width: Int, let height: Int, let mipmap: Bool = false) -> MTLTexture {
		let descriptor: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(pixelFormat, width: width, height: height, mipmapped: mipmap)
		return mtl.device.newTextureWithDescriptor(descriptor)
	}
	public func newBuffer(let length length: Int, let options: MTLResourceOptions = .CPUCacheModeDefaultCache ) -> Buffer {
		return mtl.device.newBufferWithLength(length, options: options)
	}
	public func newBuffer(let data data: NSData, let options: MTLResourceOptions = .CPUCacheModeDefaultCache ) -> Buffer {
		return mtl.device.newBufferWithBytes(data.bytes, length: data.length, options: options)
	}
	public func newBuffer(let buffer: [Float], let options: MTLResourceOptions = .CPUCacheModeDefaultCache ) -> Buffer {
		return mtl.device.newBufferWithBytes(buffer, length: sizeof(Float)*buffer.count, options: options)
	}
	internal func newBufferFromBuffer(let buffer: MTLBuffer) -> [Float] {
		let result: [Float] = [Float](count: buffer.length/sizeof(Float), repeatedValue: 0)
		let cache: MTLBuffer = newBuffer(length: buffer.length, options: .CPUCacheModeDefaultCache)
		func complete() {
			NSData(bytesNoCopy: cache.contents(), length: cache.length, freeWhenDone: false).getBytes(UnsafeMutablePointer<Void>(result), length: sizeof(Float)*result.count)
			cache.setPurgeableState(.Empty)
		}
		newBlitCommand(complete: complete) {
			$0.copyFromBuffer(buffer, sourceOffset: 0, toBuffer: cache, destinationOffset: 0, size: min(buffer.length, cache.length))
		}
		return result
	}
	internal func newBufferFromRowMajorMatrix(let buffer: [Float], let rows: Int, let cols: Int, let options: MTLResourceOptions = .CPUCacheModeDefaultCache) -> MTLBuffer {
		assert(rows*cols==buffer.count)
		if rows == 1 || cols == 1 {
			return newBuffer(buffer, options: options)
		} else {
			let result: MTLBuffer = newBuffer(length: sizeof(Float)*rows*cols, options: options)
			let cache: MTLBuffer = newBuffer(buffer, options: .StorageModePrivate)
			let group: MTLSize = MTLSize(width: cols/4, height: rows/4, depth: 1)
			let local: MTLSize = MTLSize(width: 1, height: 1, depth: 1)
			newComputeCommand(function: "fromRowMajorMatrix", complete: { cache.setPurgeableState(.Empty) }) {
				$0.setBuffer(result, offset: 0, atIndex: 0)
				$0.setBuffer(cache, offset: 0, atIndex: 1)
				$0.setBytes([uint(cols/4), uint(rows/4)], length: sizeof(uint)*2, atIndex: 2)
				$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
			}
			return result
		}
	}
	internal func newBufferFromLAObject(let matrix: la_object_t, let options: MTLResourceOptions = .CPUCacheModeDefaultCache) -> MTLBuffer {
		let rows: Int = Int(la_matrix_rows(matrix))
		let cols: Int = Int(la_matrix_cols(matrix))
		return newBufferFromRowMajorMatrix(matrix.array, rows: rows, cols: cols)
		/*
		let result: MTLBuffer = newBuffer(length: sizeof(Float)*rows*cols, options: options)
		let cache: MTLBuffer = newBuffer(length: sizeof(Float)*rows*cols, options: .CPUCacheModeDefaultCache)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache.contents()), la_count_t(cols), matrix)
		cache.didModifyRange(NSRange(location: 0, length: cache.length))
		if rows * cols == 0 {
			assertionFailure()
		}
		else if rows == 1 || cols == 1 {
			newBlitCommand(complete: { cache.setPurgeableState(.Empty) }) {
				$0.copyFromBuffer(cache, sourceOffset: 0, toBuffer: result, destinationOffset: 0, size: min(cache.length, result.length))
			}
		} else {
			let group: MTLSize = MTLSize(width: cols/4, height: rows/4, depth: 1)
			let local: MTLSize = MTLSize(width: 1, height: 1, depth: 1)
			newComputeCommand(function: "fromRowMajorMatrix", complete: { cache.setPurgeableState(.Empty) }) {
				$0.setBuffer(result, offset: 0, atIndex: 0)
				$0.setBuffer(cache, offset: 0, atIndex: 1)
				$0.setBytes([uint(cols/4), uint(rows/4)], length: sizeof(uint)*2, atIndex: 2)
				$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
			}
		}
		return result
		*/
	}
	internal func newRowMajorMatrixFromBuffer(let buffer: MTLBuffer, let rows: Int, let cols: Int) -> [Float] {
		assert(0<rows)
		assert(0<cols)
		var result: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		if buffer.length == sizeof(Float) * rows * cols {
			let cache: MTLBuffer = newBuffer(length: sizeof(Float)*rows*cols, options: .CPUCacheModeDefaultCache)
			func complete() {
				NSData(bytesNoCopy: cache.contents(), length: cache.length, freeWhenDone: false).getBytes(UnsafeMutablePointer<Void>(result), length: sizeof(Float)*result.count)
				cache.setPurgeableState(.Empty)
			}
			if rows == 1 || cols == 1 {
				newBlitCommand(complete: complete) {
					$0.copyFromBuffer(buffer, sourceOffset: 0, toBuffer: cache, destinationOffset: 0, size: sizeof(Float)*rows*cols)
				}
			} else {
				let group: MTLSize = MTLSize(width: cols/4, height: rows/4, depth: 1)
				let local: MTLSize = MTLSize(width: 1, height: 1, depth: 1)
				newComputeCommand(function: "toRowMajorMatrix", complete: complete) {
					$0.setBuffer(cache, offset: 0, atIndex: 0)
					$0.setBuffer(buffer, offset: 0, atIndex: 1)
					$0.setBytes([UInt32(rows/4)], length: sizeof(UInt32), atIndex: 2)
					$0.setBytes([UInt32(cols/4)], length: sizeof(UInt32), atIndex: 3)
					$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
				}
			}
			
		} else {
			assertionFailure()
			
		}
		return result
	}
	internal func newBufferFromLaObject(let matrix: la_object_t, let options: MTLResourceOptions = .CPUCacheModeDefaultCache) -> MTLBuffer {
		let object: la_object_t = matrix.T
		let cols: Int = Int(la_matrix_cols(object))
		let rows: Int = Int(la_matrix_rows(object))
		let cache: [Float] = [Float](count: rows*cols, repeatedValue: 0)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(cols), object)
		return newBuffer(cache, options: options)
	}
	internal func newLaObjectFromBuffer(let buffer: MTLBuffer, let rows: Int, let cols: Int, let attribute: la_attribute_t = Config.ATTR) -> la_object_t {
		let pool: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*rows*cols))
		let cache: MTLBuffer = newBuffer(length: buffer.length, options: .CPUCacheModeDefaultCache)
		newBlitCommand(complete: { NSData(bytesNoCopy: cache.contents(), length: cache.length, freeWhenDone: false).getBytes(pool, length: buffer.length); cache.setPurgeableState(.Empty)}) {
			$0.copyFromBuffer(buffer, sourceOffset: 0, toBuffer: cache, destinationOffset: 0, size: buffer.length)
		}
		return la_matrix_from_float_buffer_nocopy(pool, la_count_t(cols), la_count_t(rows), la_count_t(rows), la_hint_t(LA_NO_HINT), { free($0) }, attribute).T
	}
	public func join() {
		let command: MTLCommandBuffer = mtl.queue.commandBuffer()
		command.commit()
		command.waitUntilCompleted()
	}
}
extension Context {
	public func store ( let async async: Bool = false, let handle: (ErrorType -> Void)? = nil ) {
		( async ? performBlock : performBlockAndWait ) {
			do {
				try self.save()
			} catch let e {
				handle?(e)
			}
		}
	}
	public func purge ( let async async: Bool = false, let object: NSManagedObject ) {
		( async ? performBlock : performBlockAndWait ) {
			self.deleteObject(object)
		}
	}
	internal func new <T: NSManagedObject>() -> T? {
		var result: T?
		performBlockAndWait {
			if let name: String = NSStringFromClass(T.self).componentsSeparatedByString(".").last, object: NSManagedObject = NSEntityDescription.insertNewObjectForEntityForName(name, inManagedObjectContext: self) {
				if let sametype: T = object as? T {
					result = sametype
				} else {
					self.deleteObject(object)
				}
			}
		}
		return result
	}
	internal func fetch <T: NSManagedObject>( let attribute: [String: AnyObject] = [:] ) -> [T] {
		var result: [T] = []
		performBlockAndWait {
			if let name: String = NSStringFromClass(T.self).componentsSeparatedByString(".").last {
				let request: NSFetchRequest = NSFetchRequest(entityName: name)
				if !attribute.isEmpty {
					request.predicate = NSPredicate(format: attribute.keys.map{"\($0) = %@"}.joinWithSeparator(" and "), argumentArray: Array<AnyObject>(attribute.values))
				}
				do {
					let fetched: [AnyObject] = try self.executeFetchRequest(request)
					if let sametype: [T] = fetched as? [T] {
						result = sametype
					} else {
						assertionFailure()
					}
				} catch {
					assertionFailure()
				}
			}
		}
		return result
	}
}
