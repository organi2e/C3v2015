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
import simd

public class Context: NSManagedObjectContext {
	
	private let dispatch: (queue: dispatch_queue_t, semaphore: dispatch_semaphore_t) = (
		queue: dispatch_queue_create(Config.dispatch.serial, DISPATCH_QUEUE_SERIAL),
		semaphore: dispatch_semaphore_create(1)
	)
	
	public let storage: NSURL?
	public let platform: Platform
	
	private let rng: NSFileHandle
	private let computer: Computer
	
	public init( let storage nsurl: NSURL? = nil, let platformHint hint: Platform = .GPU ) throws {
		if hint == .GPU, let device: MTLDevice = MTLCreateSystemDefaultDevice() {
			computer = try mtlComputer(device: device)
			platform = .GPU
		}
		else {
			computer = cpuComputer()
			platform = .CPU
		}
		rng = try NSFileHandle(forReadingFromURL: Config.rngurl)
		storage = nsurl
		super.init(concurrencyType: .PrivateQueueConcurrencyType)
		
		guard let url: NSURL = Config.bundle.URLForResource(Config.coredata.name, withExtension: Config.coredata.ext) else {
			throw Error.CoreData.ModelNotFound
		}
		guard let model: NSManagedObjectModel = NSManagedObjectModel(contentsOfURL: url) else {
			throw Error.CoreData.ModelNotAvailable
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
		guard let myrng: NSFileHandle = try? NSFileHandle(forReadingFromURL: Config.rngurl) else {
			fatalError(Error.System.RNGNotFound.rawValue)
		}
		rng = myrng

		guard let hint: Platform = aDecoder.decodeObjectForKey(Context.platformKey)as?Platform else {
			fatalError(Error.System.FailObjectDecode.rawValue)
		}
		if hint == .GPU, let device: MTLDevice = MTLCreateSystemDefaultDevice() {
			computer = (try?mtlComputer(device: device)) ?? cpuComputer()
			platform = .GPU
		}
		else {
			computer = cpuComputer()
			platform = .CPU
		}
		storage = aDecoder.decodeObjectForKey(Context.storageKey)as?NSURL
		super.init(coder: aDecoder)
		guard let url: NSURL = Config.bundle.URLForResource(Config.coredata.name, withExtension: Config.coredata.ext) else {
			fatalError(Error.CoreData.ModelNotFound.rawValue)
		}
		guard let model: NSManagedObjectModel = NSManagedObjectModel(contentsOfURL: url) else {
			fatalError(Error.CoreData.ModelNotAvailable.rawValue)
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
	private static let platformKey: String = "platform"
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
	public func join ( ) {
		
	}
}
internal extension Context {
	internal func newBuffer ( let length length: Int ) -> Buffer {
		return newBuffer(data: NSData(bytes: [UInt8](count: length, repeatedValue: 0), length: length))
	}
	internal func newBuffer ( let data data: NSData ) -> Buffer {
		return computer.newBuffer(data: data)
	}
	internal func sync (let task task: (()->())) {
		computer.sync ( task )
	}
	internal func async (let task task: (()->())) {
		computer.async ( task )
	}
}
internal extension Context {
	func entropy ( let buffer: Buffer ) {
		rng.readDataOfLength(buffer.raw.length).getBytes(UnsafeMutablePointer(buffer.raw.bytes), length: buffer.raw.length)
	}
}
