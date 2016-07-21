//
//  Context.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//
import NLA
import Accelerate
import CoreData
import simd

public class Context: NSManagedObjectContext {
	
	private let dispatch: (queue: dispatch_queue_t, semaphore: dispatch_semaphore_t) = (
		queue: dispatch_queue_create(Config.dispatch.serial, DISPATCH_QUEUE_SERIAL),
		semaphore: dispatch_semaphore_create(1)
	)
	public let unit: Unit
	public let storage: NSURL?
	public init( let storage nsurl: NSURL? = nil ) throws {
		storage = nsurl
		guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
			throw Error.Metal.NoDeviceFound
		}
		unit = try Unit(device: device)
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
		do {
			guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
				throw Error.Metal.NoDeviceFound
			}
			unit = try Unit(device: device)
		} catch Unit.Error.LibraryNotAvailable {
			fatalError(Error.Metal.NoLibraryFound.description)
		} catch Unit.Error.PipelineNotAvailable(let function) {
			fatalError("Pipeline \(function) not found")
		} catch Error.Metal.NoDeviceFound {
			fatalError(Error.Metal.NoDeviceFound.description)
		} catch {
			fatalError(Error.Metal.NoLibraryFound.description)
		}
		storage = aDecoder.decodeObjectForKey(Context.storageKey)as?NSURL
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
public class C3Object: NSManagedObject {
	static let HINT: la_hint_t =  la_hint_t(LA_NO_HINT)
	static let ATTR: la_attribute_t = la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)

	lazy var unit: Unit = {
		guard let context: Context = self.managedObjectContext as? Context else {
			assertionFailure()
			fatalError()
		}
		return context.unit
	}()
}
func +(let lhs: la_object_t, let rhs: la_object_t)->la_object_t {
	return la_sum(lhs, rhs)
}
func -(let lhs: la_object_t, let rhs: la_object_t)->la_object_t {
	return la_difference(lhs, rhs)
}
func *(let lhs: la_object_t, let rhs: la_object_t)->la_object_t {
	return la_elementwise_product(lhs, rhs)
}
extension Context {
	private static let storageKey: String = "storage"
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
}
