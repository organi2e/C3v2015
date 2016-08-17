//
//  Context.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//
import Accelerate
import Metal
import Cocoa
import CoreData

public class Context: NSManagedObjectContext {
	
	enum Error: String, ErrorType {
		case InvalidContext = "InvalidContext"
		enum CoreData: ErrorType, CustomStringConvertible {
			case NoModelFound
			case NoModelAvailable
			case InsertionFails(entity: String)
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
		let pipeline: [String: MTLComputePipelineState]
		init(let device mtldevice: MTLDevice) throws {
			guard let libpath: String = NSBundle(forClass: Context.self).pathForResource("default", ofType: "metallib"), library: MTLLibrary = try? mtldevice.newLibraryWithFile(libpath) else {
				throw Error.Metal.NoLibraryFound
			}
			var kernels: [String: MTLComputePipelineState] = [:]
			try library.functionNames.forEach {
				guard let function: MTLFunction = library.newFunctionWithName($0) else {
					throw Error.Metal.PipelineNotAvailable(function: $0)
				}
				kernels[$0] = try mtldevice.newComputePipelineStateWithFunction(function)
			}
			device = mtldevice
			queue = device.newCommandQueue()
			pipeline = kernels
		}
	}
	
	private let mtl: MTL
	private let storage: NSURL?
	
	public init( let storage storageurl: NSURL? = nil, let device: MTLDevice? = MTLCreateSystemDefaultDevice() ) throws {
		
		guard let device: MTLDevice = device else {
			throw Error.Metal.NoDeviceFound
		}
		
		mtl = try MTL(device: device)
		storage = storageurl
		
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
	
	internal func newRenderCommand(let sync sync: Bool, let drawable: CAMetalDrawable, let color: MTLClearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0), let configure: (MTLRenderCommandEncoder->())) {
		let x: MTLRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
		
	}
	internal func newComputeCommand ( let sync sync: Bool = false, let function: String, let schedule: (()->())? = nil, let complete: (()->())? = nil, let configure: (MTLComputeCommandEncoder->())) {
		if let pipeline: MTLComputePipelineState = mtl.pipeline[function] {
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
			assertionFailure(function)
			
		}
	}
	internal func newBlitCommand( let sync sync: Bool = false, let schedule: (()->())? = nil, let complete: (()->())? = nil, let configure: (MTLBlitCommandEncoder->())) {
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
	internal func newBuffer(let length length: Int, let options: MTLResourceOptions = .CPUCacheModeDefaultCache ) -> MTLBuffer {
		return mtl.device.newBufferWithLength(length, options: options)
	}
	internal func newBuffer(let data data: NSData, let options: MTLResourceOptions = .CPUCacheModeDefaultCache ) -> MTLBuffer {
		return mtl.device.newBufferWithBytes(data.bytes, length: data.length, options: options)
	}
	internal func newBuffer(let buffer: [Float], let options: MTLResourceOptions = .CPUCacheModeDefaultCache ) -> MTLBuffer {
		return mtl.device.newBufferWithBytes(buffer, length: sizeof(Float)*buffer.count, options: options)
	}
	internal func fromLAObject(let matrix: la_object_t, let options: MTLResourceOptions = .CPUCacheModeDefaultCache) -> MTLBuffer {
		let rows: Int = Int(la_matrix_rows(matrix))
		let cols: Int = Int(la_matrix_cols(matrix))
		if rows * cols == 0 {
			assertionFailure()
			return newBuffer(length: 0)
		}
		else if rows == 1 || cols == 1 {
			let length: Int = Int(la_vector_length(matrix))
			let semaphore: dispatch_semaphore_t = dispatch_semaphore_create(0)
			let result: MTLBuffer = newBuffer(length: sizeof(Float)*length, options: options)
			let cache: MTLBuffer = newBuffer(length: sizeof(Float)*length, options: .CPUCacheModeDefaultCache)
			performBlock {
				la_vector_to_float_buffer(UnsafeMutablePointer<Float>(cache.contents()), la_index_t(1), matrix)
				dispatch_semaphore_signal(semaphore)
			}
			newBlitCommand(schedule: { dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER) }, complete: { cache.setPurgeableState(.Empty) }) {
				$0.copyFromBuffer(cache, sourceOffset: 0, toBuffer: result, destinationOffset: 0, size: min(cache.length, result.length))
			}
			return result
			
		} else {
			let semaphore: dispatch_semaphore_t = dispatch_semaphore_create(0)
			let result: MTLBuffer = mtl.device.newBufferWithLength(sizeof(Float)*rows*cols, options: options)
			let cache: MTLBuffer = mtl.device.newBufferWithLength(sizeof(Float)*rows*cols, options: .CPUCacheModeDefaultCache)
			performBlock {
				la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache.contents()), la_count_t(cols), matrix)
				dispatch_semaphore_signal(semaphore)
			}
			let group: MTLSize = MTLSize(width: cols/4, height: rows/4, depth: 1)
			let local: MTLSize = MTLSize(width: 1, height: 1, depth: 1)
			newComputeCommand(function: "fromRowMajorMatrix", schedule: { dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER) }, complete: { cache.setPurgeableState(.Empty) }) {
				$0.setBuffer(result, offset: 0, atIndex: 0)
				$0.setBuffer(cache, offset: 0, atIndex: 1)
				$0.setBytes([UInt32(rows/4)], length: sizeof(UInt32), atIndex: 2)
				$0.setBytes([UInt32(cols/4)], length: sizeof(UInt32), atIndex: 3)
				$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
			}
			return result
		
		}
	}
	internal func toLAObject(let buffer: MTLBuffer, let rows: Int, let cols: Int, let attribute: la_attribute_t = Config.ATTR) -> la_object_t {
		let pool: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(malloc(sizeof(Float)*rows*cols))
		let cache: MTLBuffer = newBuffer(length: buffer.length)
		if rows == 1 || cols == 1 {
			newBlitCommand(complete: { NSData(bytesNoCopy: cache.contents(), length: cache.length, freeWhenDone: false).getBytes(pool, length: buffer.length); cache.setPurgeableState(.Empty)}) {
				$0.copyFromBuffer(buffer, sourceOffset: 0, toBuffer: cache, destinationOffset: 0, size: buffer.length)
			}
		
		} else {
			let group: MTLSize = MTLSize(width: cols/4, height: rows/4, depth: 1)
			let local: MTLSize = MTLSize(width: 1, height: 1, depth: 1)
			newComputeCommand(function: "toRowMajorMatrix", complete: { NSData(bytesNoCopy: cache.contents(), length: cache.length, freeWhenDone: false).getBytes(pool, length: sizeof(Float)*rows*cols); cache.setPurgeableState(.Empty); }) {
				$0.setBuffer(cache, offset: 0, atIndex: 0)
				$0.setBuffer(buffer, offset: 0, atIndex: 1)
				$0.setBytes([UInt32(rows/4)], length: sizeof(UInt32), atIndex: 2)
				$0.setBytes([UInt32(cols/4)], length: sizeof(UInt32), atIndex: 3)
				$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
			}
		
		}
		return la_matrix_from_float_buffer_nocopy(pool, la_count_t(rows), la_count_t(cols), la_count_t(cols), la_hint_t(LA_NO_HINT), { free($0) }, attribute)
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