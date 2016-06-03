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

public class Context {
	let context: NSManagedObjectContext
	let device: MTLDevice
	let library: MTLLibrary
	let queue: MTLCommandQueue
	public init ( let storage: NSURL? = nil ) throws {
		context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
		(device, library) = try {
			guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
				throw NSError(domain: "", code: 404, userInfo: nil)
			}
			guard let path: String = NSBundle(forClass: Context.self).pathForResource("default", ofType: "metallib"), library: MTLLibrary = try device.newLibraryWithFile(path) else {
				throw NSError(domain: "Metal: Library", code: 0, userInfo: nil)
			}
			return(device, library)
		}()
		queue = device.newCommandQueue()
		
		let bundle: NSBundle = NSBundle(forClass: Context.self)
		guard let url: NSURL = bundle.URLForResource("C3", withExtension: "momd") else {
			throw NSError(domain: "Core Data: Model", code: 404, userInfo: nil)
		}
		guard let model: NSManagedObjectModel = NSManagedObjectModel(contentsOfURL: url) else {
			throw NSError(domain: "Core Data: Model", code: 500, userInfo: nil)
		}
		context.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
		try context.persistentStoreCoordinator?.addPersistentStoreWithType(storage == nil ? NSInMemoryStoreType : NSSQLiteStoreType, configuration: nil, URL: storage, options: nil)
	}
	public func sync ( let task: ( ) -> ( ) ) {
		context.performBlockAndWait ( task )
	}
	public func async ( let task: ( ) -> ( ) ) {
		context.performBlock ( task )
	}
	public func save ( ) throws {
		var error: NSError?
		sync {
			do {
				try self.context.save()
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
		sync {
			if let
				name: String = NSStringFromClass(T.self).componentsSeparatedByString(".").last,
				object: NSManagedObject = NSEntityDescription.insertNewObjectForEntityForName(name, inManagedObjectContext: self.context)
			{
				if let sametype: T = object as? T {
					result = sametype
				} else {
					self.context.deleteObject(object)
				}
			}
		}
		return result
	}
	internal func fetch <T: NSManagedObject>( let attribute: [String: AnyObject] = [:] ) -> [T] {
		var result: [T] = []
		sync {
			if let name: String = NSStringFromClass(T.self).componentsSeparatedByString(".").last {
				let request: NSFetchRequest = NSFetchRequest(entityName: name)
				if !attribute.isEmpty {
				request.predicate = NSPredicate(format: attribute.keys.map{"\($0) = %@"}.joinWithSeparator(" and "), argumentArray: Array<AnyObject>(attribute.values))
				}
				if let fetched: [AnyObject] = try? self.context.executeFetchRequest ( request ) {
					if let sametype: [T] = fetched as? [T] {
						result = sametype
					}
				}
			}
		}
		return result
	}
	internal func purge ( let object: NSManagedObject ) {
		sync {
			self.context.deleteObject(object)
		}
	}
	internal func shared ( let data: NSData ) -> (NSData, MTLBuffer) {
		let mtlbuffer: MTLBuffer = device.newBufferWithBytes(data.bytes, length: data.length, options: .CPUCacheModeDefaultCache)
		let nsdata: NSData = NSData(bytesNoCopy: mtlbuffer.contents(), length: mtlbuffer.length, freeWhenDone: false)
		return(nsdata, mtlbuffer)
	}
}
