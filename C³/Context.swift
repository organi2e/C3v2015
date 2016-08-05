//
//  Context.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//
import Accelerate
import Metal
import CoreData

public class Context: NSManagedObjectContext {
	
	enum Error: ErrorType, CustomStringConvertible {
		case InvalidContext
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
		var description: String {
			return ""
		}
	}
	
	internal let dispatch: (serial: dispatch_queue_t, parallel: dispatch_queue_t) = (
		serial: dispatch_queue_create(Config.dispatch.serial, DISPATCH_QUEUE_SERIAL),
		parallel: dispatch_queue_create(Config.dispatch.parallel, DISPATCH_QUEUE_CONCURRENT)
	)
	
	struct MTL {
		let device: MTLDevice
		let queue: MTLCommandQueue
		struct Kernels {
			let vmsa: MTLComputePipelineState
			let smvmv: MTLComputePipelineState
			let gemv: MTLComputePipelineState
			let gemm: MTLComputePipelineState
			let gauss: MTLComputePipelineState
		}
		let kernels: Kernels
		init(let device mtldevice: MTLDevice) throws {
			guard let libpath: String = NSBundle(forClass: Context.self).pathForResource("default", ofType: "metallib"), library: MTLLibrary = try? mtldevice.newLibraryWithFile(libpath) else {
				throw Error.Metal.NoLibraryFound
			}
			let pipeline: String throws -> MTLComputePipelineState = {
				guard let function: MTLFunction = library.newFunctionWithName($0) else {
					throw Error.Metal.PipelineNotAvailable(function: $0)
				}
				return try mtldevice.newComputePipelineStateWithFunction(function)
			}
			device = mtldevice
			queue = device.newCommandQueue()
			kernels = Kernels(vmsa: try pipeline("vsma"),
			                  smvmv: try pipeline("smvmv"),
			                  gemv: try pipeline("gemv"),
			                  gemm: try pipeline("gemm"),
			                  gauss: try pipeline("gauss")
			)
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
	internal func axpy(let y: MTLBuffer, let x: MTLBuffer, let alpha: Float) {
		
		assert(y.length==x.length)
		
		let command: MTLCommandBuffer = mtl.queue.commandBuffer()
		let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
		encoder.setComputePipelineState(mtl.kernels.vmsa)
		encoder.setBuffer(y, offset: 0, atIndex: 0)
		encoder.setBuffer(x, offset: 0, atIndex: 1)
		encoder.setBytes([alpha], length: 0, atIndex: 2)
		encoder.dispatchThreadgroups(MTLSize(width: y.length/sizeof(Float)/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		encoder.endEncoding()
		command.commit()
		
	}
	internal func smvmv(let y: MTLBuffer, let alpha: Float, let a: MTLBuffer, let b: MTLBuffer ) {
		
		assert(y.length==a.length)
		assert(y.length==b.length)
		
		let command: MTLCommandBuffer = mtl.queue.commandBuffer()
		let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
		encoder.setComputePipelineState(mtl.kernels.smvmv)
		encoder.setBuffer(y, offset: 0, atIndex: 0)
		encoder.setBytes([alpha], length: 0, atIndex: 1)
		encoder.setBuffer(a, offset: 0, atIndex: 2)
		encoder.setBuffer(b, offset: 0, atIndex: 3)
		encoder.dispatchThreadgroups(MTLSize(width: y.length/sizeof(Float)/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		encoder.endEncoding()
		command.commit()
		
	}
	internal func shuffle(let value: MTLBuffer, let deviation: MTLBuffer, let variance: MTLBuffer, let mean: MTLBuffer, let logvariance: MTLBuffer) {
		
		assert(value.length==deviation.length)
		assert(deviation.length==variance.length)
		assert(variance.length==mean.length)
		assert(mean.length==logvariance.length)
		
		let semaphore: dispatch_semaphore_t = dispatch_semaphore_create(0)
		let cache: MTLBuffer = mtl.device.newBufferWithLength(value.length, options: .CPUCacheModeDefaultCache)
		
		dispatch_async(dispatch.parallel) { arc4random_buf(cache.contents(), cache.length); dispatch_semaphore_signal(semaphore) }
		
		let command: MTLCommandBuffer = mtl.queue.commandBuffer()
		let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
		
		encoder.setComputePipelineState(mtl.kernels.gauss)
		encoder.setBuffer(value, offset: 0, atIndex: 0)
		encoder.setBuffer(deviation, offset: 0, atIndex: 0)
		encoder.setBuffer(variance, offset: 0, atIndex: 0)
		encoder.setBuffer(mean, offset: 0, atIndex: 0)
		encoder.setBuffer(logvariance, offset: 0, atIndex: 0)
		encoder.setBuffer(cache, offset: 0, atIndex: 0)
		encoder.dispatchThreadgroups(MTLSize(width: value.length/sizeof(Float)/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		encoder.endEncoding()
		
		command.addScheduledHandler { (_)in dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER) }
		command.addCompletedHandler { (_)in cache.setPurgeableState(.Empty) }
		command.commit()
		
	}
	internal func newBuffer(let length length: Int, let options: MTLResourceOptions = MTLResourceOptions.CPUCacheModeDefaultCache ) -> MTLBuffer {
		return mtl.device.newBufferWithLength(length, options: options)
	}
	internal func newBuffer(let data data: NSData, let options: MTLResourceOptions = MTLResourceOptions.CPUCacheModeDefaultCache ) -> MTLBuffer {
		return mtl.device.newBufferWithBytes(data.bytes, length: data.length, options: options)
	}
	internal func fill(let buffer buffer: MTLBuffer, let range: NSRange, let value: UInt8 = 0) {
		let command: MTLCommandBuffer = mtl.queue.commandBuffer()
		let encoder: MTLBlitCommandEncoder = command.blitCommandEncoder()
		encoder.fillBuffer(buffer, range: range, value: value)
		encoder.endEncoding()
		command.commit()
	}
	internal func copy(let destination destination: MTLBuffer, let destinationOffset: Int, let source: MTLBuffer, let sourceOffset: Int, let size: Int ) {
		let command: MTLCommandBuffer = mtl.queue.commandBuffer()
		let encoder: MTLBlitCommandEncoder = command.blitCommandEncoder()
		encoder.copyFromBuffer(source, sourceOffset: sourceOffset, toBuffer: destination, destinationOffset: destinationOffset, size: size)
		encoder.endEncoding()
		command.commit()
	}
	internal func copy(let destination destination: MTLBuffer, let source: NSData ) {
		let command: MTLCommandBuffer = mtl.queue.commandBuffer()
		command.addCompletedHandler {(_)in
			source.getBytes(destination.contents(), length: destination.length)
		}
		command.commit()
	}
	internal func join() {
		let cmd: MTLCommandBuffer = mtl.queue.commandBuffer()
		cmd.commit()
		cmd.waitUntilCompleted()
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