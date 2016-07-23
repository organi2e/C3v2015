//
//  Blob.swift
//  C³
//
//  Created by Kota Nakano on 7/23/16.
//
//

import CoreData
public class Blob: NSManagedObject {
	public override func awakeFromInsert() {
		super.awakeFromInsert()
		setPrimitiveValue("", forKey: "name")
		setPrimitiveValue(NSData(), forKey: "data")
	}
	public override func awakeFromFetch() {
		super.awakeFromFetch()
		setPrimitiveValue(NSData(bytes: data.bytes, length: data.length), forKey: "data")
	}
	public override func awakeFromSnapshotEvents(flags: NSSnapshotEventType) {
		super.awakeFromSnapshotEvents(flags)
		setPrimitiveValue(NSData(bytes: data.bytes, length: data.length), forKey: "data")
	}
}
extension Blob {
	@NSManaged var name: String
	@NSManaged var data: NSData
}
extension Blob {
	internal func resize(let index: Int) {
		if index < data.length {
		
		} else {
			let buff: [UInt8] = [UInt8](count: index+1, repeatedValue: 0)
			data.getBytes(UnsafeMutablePointer<Void>(buff), length: index+1)
			setPrimitiveValue(NSData(bytes: buff, length: index+1), forKey: "data")
		}
	}
	public subscript(let index: UInt) -> UInt8 {
		get {
			resize(Int(index))
			willAccessValueForKey("data")
			defer { didAccessValueForKey("data") }
			return UnsafeMutablePointer<UInt8>(data.bytes).advancedBy(Int(index)).memory
		}
		set {
			resize(Int(index))
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
