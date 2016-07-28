//
//  Context.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//
import Accelerate
import CoreData

public class Context: NSManagedObjectContext {
	internal let dispatch: (serial: dispatch_queue_t, parallel: dispatch_queue_t) = (
		serial: dispatch_queue_create(Config.dispatch.serial, DISPATCH_QUEUE_SERIAL),
		parallel: dispatch_queue_create(Config.dispatch.parallel, DISPATCH_QUEUE_CONCURRENT)
	)
	public let storage: NSURL?
	public init( let storage nsurl: NSURL? = nil ) throws {
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
		aCoder.encodeObject(storage, forKey: "storage")
	}
	required public init?(coder aDecoder: NSCoder) {
		storage = aDecoder.decodeObjectForKey("storage")as?NSURL
		super.init(coder: aDecoder)
		guard let url: NSURL = Config.bundle.URLForResource(Config.coredata.name, withExtension: Config.coredata.ext) else {
			fatalError(Error.CoreData.ModelNotFound.description)
		}
		guard let model: NSManagedObjectModel = NSManagedObjectModel(contentsOfURL: url) else {
			fatalError(Error.CoreData.ModelNotAvailable.description)
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
extension Context {
	public func join() {
		/*
		dispatch_barrier_sync(dispatch.parallel) {
			self.performBlockAndWait {
				self.registeredObjects.forEach {
					switch $0 {
					case let cell as Cell:
						if let mean: NSData = cell.valueForKey("mean")as?NSData {
							cell.setValue(NSData(data: mean), forKey: "mean")
						}
						if let logvariance: NSData = cell.valueForKey("logvariance")as?NSData {
							cell.setValue(NSData(data: logvariance), forKey: "logvariance")
						}
						print("join cell")
					case let edge as Edge:
						if let mean: NSData = edge.valueForKey("mean")as?NSData {
							edge.setValue(NSData(data: mean), forKey: "mean")
						}
						if let logvariance: NSData = edge.valueForKey("logvariance")as?NSData {
							edge.setValue(NSData(data: logvariance), forKey: "logvariance")
						}
						print("join edge")
					default:
						break
					}
				}
			}
		}
		*/
	}
}