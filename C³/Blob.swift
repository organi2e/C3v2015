//
//  Blob.swift
//  C³
//
//  Created by Kota Nakano on 7/23/16.
//
//

import CoreData
public class Blob: NSManagedObject {
	public override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
		super.init(entity: entity, insertIntoManagedObjectContext: context)
		key = ""
		data = NSData()
	}
}
extension Blob {
	@NSManaged var key: String
	@NSManaged var data: NSData
}
extension Blob {
	public subscript(let index: UInt) -> UInt8 {
		get {
			willAccessValueForKey("data")
			defer { didAccessValueForKey("data") }
			return UnsafeMutablePointer<UInt8>(data.bytes).advancedBy(Int(index)).memory
		}
		set {
			willChangeValueForKey("data")
			defer { didChangeValueForKey("data") }
			UnsafeMutablePointer<UInt8>(data.bytes).advancedBy(Int(index)).memory = newValue
		}
	}
	public var length: Int {
		return data.length
	}
	public var bytes: UnsafeMutablePointer<Void> {
		return UnsafeMutablePointer<Void>(data.bytes)
	}
}
