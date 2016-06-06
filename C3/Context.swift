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
	private let device: MTLDevice
	private let library: MTLLibrary
	private let queue: MTLCommandQueue
	
	
	public init( let storage: NSURL? ) throws {
		(device, library) = try {
			guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
				throw MetalError.DeviceNotFound
			}
			guard let path: String = NSBundle(forClass: Context.self).pathForResource(Context.metal.name, ofType: Context.metal.ext), library: MTLLibrary = try device.newLibraryWithFile(path) else {
				throw MetalError.LibraryNotAvailable
			}
			return(device, library)
		}()
		self.queue = device.newCommandQueue()
		self.storage = storage
		guard 0 < Context.rng else { throw SystemError.RNGNotFound }
		
		let bundle: NSBundle = NSBundle(forClass: Context.self)
		guard let url: NSURL = bundle.URLForResource(Context.coredata.name, withExtension: Context.coredata.ext) else {
			throw CoreDataError.ModelNotFound
		}
		guard let model: NSManagedObjectModel = NSManagedObjectModel(contentsOfURL: url) else {
			throw CoreDataError.ModelNotAvailable
		}
		
		super.init(concurrencyType: .PrivateQueueConcurrencyType)
		let storecoordinator: NSPersistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
		try storecoordinator.addPersistentStoreWithType(storage == nil ? NSInMemoryStoreType : NSSQLiteStoreType, configuration: nil, URL: storage, options: nil)
		persistentStoreCoordinator = storecoordinator
	}
	public override func encodeWithCoder(aCoder: NSCoder) {
		super.encodeWithCoder(aCoder)
		aCoder.encodeObject(storage, forKey: Context.storageKey)
	}
	required public init?(coder aDecoder: NSCoder) {
		(device, library) = {
			guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
				fatalError(MetalError.DeviceNotFound.rawValue)
			}
			guard let path: String = NSBundle(forClass: Context.self).pathForResource(Context.metal.name, ofType: Context.metal.ext), library: MTLLibrary = try!device.newLibraryWithFile(path) else {
				fatalError(MetalError.LibraryNotAvailable.rawValue)
			}
			return(device, library)
		}()
		queue = device.newCommandQueue()
		storage = aDecoder.decodeObjectForKey(Context.storageKey)as?NSURL
		super.init(coder: aDecoder)
		
		guard 0 < Context.rng else { fatalError(SystemError.RNGNotFound.rawValue) }
		
		let bundle: NSBundle = NSBundle(forClass: Context.self)
		guard let url: NSURL = bundle.URLForResource(Context.coredata.name, withExtension: Context.coredata.ext) else {
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
		} catch let e as NSError {
			fatalError(String(e))
		}
	}
	internal func shared ( let data: NSData ) -> (NSData, MTLBuffer) {
		let mtlbuffer: MTLBuffer = device.newBufferWithBytes(data.bytes, length: data.length, options: .CPUCacheModeDefaultCache)
		let nsdata: NSData = NSData(bytesNoCopy: mtlbuffer.contents(), length: mtlbuffer.length, freeWhenDone: false)
		return(nsdata, mtlbuffer)
	}
}
extension Context {
	private static let rng: Int32 = open(Config.rng, O_RDONLY)
	private static let storageKey: String = "storage"
	private static let coredata: (name: String, ext: String) = (name: "C3", ext: "momd")
	private static let metal: (name: String, ext: String) = (name: "default", ext: "metallib")
	private static let dispatch: (queue: dispatch_queue_t, semaphore: dispatch_semaphore_t) = (
		queue: dispatch_queue_create(Config.dispatch.parallel, DISPATCH_QUEUE_CONCURRENT),
		semaphore: dispatch_semaphore_create(1)
	)
}
extension Context {
	public func store ( ) throws {
		var error: NSError?
		performBlockAndWait {
			do {
				try self.save()
			} catch let e as NSError {
				error = e
			}
		}
		if let error: NSError = error {
			throw error
		}
	}
	internal func new <T: NSManagedObject>() -> T? {
		var result: T?
		performBlockAndWait {
			if let
				name: String = NSStringFromClass(T.self).componentsSeparatedByString(".").last,
				object: NSManagedObject = NSEntityDescription.insertNewObjectForEntityForName(name, inManagedObjectContext: self)
			{
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
	internal func allocate ( let length: Int ) -> MTLBuffer {
		return device.newBufferWithLength(length, options: .CPUCacheModeDefaultCache)
	}
	internal func allocates ( let data: NSData ) -> ( NSData, MTLBuffer ) {
		let mtlbuf: MTLBuffer = device.newBufferWithBytes(data.bytes, length: data.length, options: .CPUCacheModeDefaultCache)
		return(NSData(bytesNoCopy: mtlbuf.contents(), length: mtlbuf.length, freeWhenDone: false), mtlbuf)
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
internal protocol CoreDataSharedMetal {
	func reallocate ()
}