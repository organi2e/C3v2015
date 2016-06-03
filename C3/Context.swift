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
	
	let storage: NSURL?
	
	let device: MTLDevice
	let library: MTLLibrary
	let queue: MTLCommandQueue
	
	public init( let storage: NSURL? ) throws {
		(device, library) = try {
			guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
				throw NSError(domain: "", code: 404, userInfo: nil)
			}
			guard let path: String = NSBundle(forClass: Context.self).pathForResource("default", ofType: "metallib"), library: MTLLibrary = try device.newLibraryWithFile(path) else {
				throw NSError(domain: "Metal: Library", code: 0, userInfo: nil)
			}
			return(device, library)
		}()
		
		self.queue = device.newCommandQueue()
		self.storage = storage
		
		let bundle: NSBundle = NSBundle(forClass: Context.self)
		guard let url: NSURL = bundle.URLForResource("C3", withExtension: "momd") else {
			throw NSError(domain: "C3.framework", code: 404, userInfo: ["Reason": "Model not found"])
		}
		guard let model: NSManagedObjectModel = NSManagedObjectModel(contentsOfURL: url) else {
			throw NSError(domain: "C3.framework", code: 500, userInfo: ["Reason": "Model was broken"])
		}
		super.init(concurrencyType: .PrivateQueueConcurrencyType)
		persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
		try persistentStoreCoordinator?.addPersistentStoreWithType(storage == nil ? NSInMemoryStoreType : NSSQLiteStoreType, configuration: nil, URL: storage, options: nil)
	}
	required public init?(coder aDecoder: NSCoder) {
		(device, library) = {
			guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
				fatalError("This platform does not support Metal API")
			}
			guard let path: String = NSBundle(forClass: Context.self).pathForResource("default", ofType: "metallib"), library: MTLLibrary = try!device.newLibraryWithFile(path) else {
				fatalError("Metal API Library might be broken")
			}
			return(device, library)
		}()
		queue = device.newCommandQueue()
		storage = nil
		super.init(coder: aDecoder)
		let bundle: NSBundle = NSBundle(forClass: Context.self)
		guard let url: NSURL = bundle.URLForResource("C3", withExtension: "momd") else {
			fatalError("Model not found")
		}
		guard let model: NSManagedObjectModel = NSManagedObjectModel(contentsOfURL: url) else {
			fatalError("Model was broken")
		}
		persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
		do {
			try persistentStoreCoordinator?.addPersistentStoreWithType(storage == nil ? NSInMemoryStoreType : NSSQLiteStoreType, configuration: nil, URL: storage, options: nil)
		} catch let e as NSError {
			fatalError(String(e))
		}
	}
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
	internal func shared ( let data: NSData ) -> (NSData, MTLBuffer) {
		let mtlbuffer: MTLBuffer = device.newBufferWithBytes(data.bytes, length: data.length, options: .CPUCacheModeDefaultCache)
		let nsdata: NSData = NSData(bytesNoCopy: mtlbuffer.contents(), length: mtlbuffer.length, freeWhenDone: false)
		return(nsdata, mtlbuffer)
	}
}