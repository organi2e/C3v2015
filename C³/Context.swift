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
	internal func newComputeCommand ( let sync sync: Bool = false, let function: String, let schedule: (()->())? = nil, let complete: (()->())? = nil, let configure: (MTLComputeCommandEncoder->())) {
		if let pipeline: MTLComputePipelineState = mtl.pipeline[function] {
			let command: MTLCommandBuffer = mtl.queue.commandBuffer()
			let encoder: MTLComputeCommandEncoder = command.computeCommandEncoder()
			encoder.setComputePipelineState(pipeline)
			configure(encoder)
			encoder.endEncoding()
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
			
		} else {
			assertionFailure(function)
			
		}
	}
	internal func newBlitCommand( let sync sync: Bool = false, let schedule: (()->())? = nil, let complete: (()->())? = nil, let configure: (MTLBlitCommandEncoder->())) {
		let command: MTLCommandBuffer = mtl.queue.commandBuffer()
		let encoder: MTLBlitCommandEncoder = command.blitCommandEncoder()
		configure(encoder)
		encoder.endEncoding()
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
	internal func join() {
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