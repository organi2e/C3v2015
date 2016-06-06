//
//  Context.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//
import CoreData
import Metal
import simd

public class Context: NSManagedObjectContext {
	
	private let dispatch: (queue: dispatch_queue_t, semaphore: dispatch_semaphore_t) = (
		queue: dispatch_queue_create(Config.dispatch.serial, DISPATCH_QUEUE_SERIAL),
		semaphore: dispatch_semaphore_create(1)
	)
	
	private let storage: NSURL?
	
	private let rng: NSFileHandle
	private let device: MTLDevice
	private let library: MTLLibrary
	private let queue: MTLCommandQueue
	
	public init( let storage nsurl: NSURL? ) throws {
		rng = try NSFileHandle(forReadingFromURL: Config.rngurl)
		(device, library) = try {
			guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
				throw MetalError.DeviceNotFound
			}
			guard let path: String = NSBundle(forClass: Context.self).pathForResource(Context.metal.name, ofType: Context.metal.ext), library: MTLLibrary = try device.newLibraryWithFile(path) else {
				throw MetalError.LibraryNotAvailable
			}
			return(device, library)
		}()
		queue = device.newCommandQueue()
		storage = nsurl
		
		super.init(concurrencyType: .PrivateQueueConcurrencyType)
		
		guard let url: NSURL = Config.bundle.URLForResource(Context.coredata.name, withExtension: Context.coredata.ext) else {
			throw CoreDataError.ModelNotFound
		}
		guard let model: NSManagedObjectModel = NSManagedObjectModel(contentsOfURL: url) else {
			throw CoreDataError.ModelNotAvailable
		}
		let storecoordinator: NSPersistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
		let storetype: String = storage == nil ? NSInMemoryStoreType : storage?.pathExtension == "sqlite" ? NSSQLiteStoreType : NSBinaryStoreType
		try storecoordinator.addPersistentStoreWithType(storetype, configuration: nil, URL: storage, options: nil)
		persistentStoreCoordinator = storecoordinator
	}
	public override func encodeWithCoder(aCoder: NSCoder) {
		super.encodeWithCoder(aCoder)
		aCoder.encodeObject(storage, forKey: Context.storageKey)
	}
	required public init?(coder aDecoder: NSCoder) {
		(device, library, rng) = {
			guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
				fatalError(MetalError.DeviceNotFound.rawValue)
			}
			guard let path: String = NSBundle(forClass: Context.self).pathForResource(Context.metal.name, ofType: Context.metal.ext), library: MTLLibrary = try!device.newLibraryWithFile(path) else {
				fatalError(MetalError.LibraryNotAvailable.rawValue)
			}
			guard let rng: NSFileHandle = try? NSFileHandle(forReadingFromURL: Config.rngurl) else {
				fatalError(SystemError.RNGNotFound.rawValue)
			}
			return(device, library, rng)
		}()
		queue = device.newCommandQueue()
		storage = aDecoder.decodeObjectForKey(Context.storageKey)as?NSURL
		
		super.init(coder: aDecoder)

		guard let url: NSURL = Config.bundle.URLForResource(Context.coredata.name, withExtension: Context.coredata.ext) else {
			fatalError(CoreDataError.ModelNotFound.rawValue)
		}
		guard let model: NSManagedObjectModel = NSManagedObjectModel(contentsOfURL: url) else {
			fatalError(CoreDataError.ModelNotAvailable.rawValue)
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
	private static let storageKey: String = "storage"
	private static let coredata: (name: String, ext: String) = (name: "C³", ext: "momd")
	private static let metal: (name: String, ext: String) = (name: "default", ext: "metallib")
	private static let dispatch: (queue: dispatch_queue_t, semaphore: dispatch_semaphore_t) = (
		queue: dispatch_queue_create(Config.dispatch.parallel, DISPATCH_QUEUE_CONCURRENT),
		semaphore: dispatch_semaphore_create(1)
	)
}
extension Context {
	public func store ( ) throws {
		var error: ErrorType?
		performBlockAndWait {
			do {
				try self.save()
			} catch let e {
				error = e
			}
		}
		if let error: ErrorType = error {
			throw error
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
				if let fetched: [AnyObject] = try? self.executeFetchRequest ( request ) {
					if let sametype: [T] = fetched as? [T] {
						result = sametype
					}
				}
			}
		}
		return result
	}
	internal func purge ( let object: NSManagedObject ) {
		performBlock {
			self.deleteObject(object)
		}
	}
	internal func allocate ( let length length: Int ) -> MTLBuffer {
		return device.newBufferWithLength(length, options: .CPUCacheModeDefaultCache)
	}
	internal func allocate ( let data data: NSData ) -> MTLBuffer {
		return device.newBufferWithBytes(data.bytes, length: data.length, options: .CPUCacheModeDefaultCache)
	}
	public func join ( ) {
		let cmd: MTLCommandBuffer = queue.commandBuffer()
		cmd.commit()
		cmd.waitUntilCompleted()
	}
}
internal extension Context {
	func entropy ( let buffer: MTLBuffer ) {
		rng.readDataOfLength(buffer.length).getBytes(buffer.contents(), length: buffer.length)
	}
}
internal extension Context {
	func newMTLCommandBuffer() -> MTLCommandBuffer {
		return queue.commandBuffer()
	}
}
internal extension NSManagedObject {
	var context: Context {
		guard let context: Context = managedObjectContext as? Context else {
			fatalError(SystemError.InvalidOperation.rawValue)
		}
		return context
	}
}
