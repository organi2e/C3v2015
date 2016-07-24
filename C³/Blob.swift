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
		setPrimitiveValue("", forKey: Blob.namekey)
		setPrimitiveValue(NSData(), forKey: Blob.datakey)
	}
	public override func awakeFromFetch() {
		super.awakeFromFetch()
		if let cache: NSData = primitiveValueForKey(Blob.datakey)as?NSData {
			setPrimitiveValue(NSData(data: cache), forKey: Blob.datakey)
		} else {
			assertionFailure()
		}
	}
}
extension Blob {
	private static let namekey: String = "name"
	private static let datakey: String = "data"
	@NSManaged var name: String
	@NSManaged var data: NSData
}
extension Blob {
	private func checksum ( let index: Int ) {
		if index < data.length {
		
		} else {
			let buff: [UInt8] = [UInt8](count: index+1, repeatedValue: 0)
			data.getBytes(UnsafeMutablePointer<Void>(buff), length: buff.count)
			setPrimitiveValue(NSData(bytes: buff, length: buff.count), forKey: Blob.datakey)
		}
	}
	public subscript ( let index: UInt ) -> UInt8 {
		get {
			checksum(Int(index))
			willAccessValueForKey(Blob.datakey)
			defer { didAccessValueForKey(Blob.datakey) }
			return UnsafeMutablePointer<UInt8>(data.bytes).advancedBy(Int(index)).memory
		}
		set {
			checksum(Int(index))
			willChangeValueForKey(Blob.datakey)
			defer { didChangeValueForKey(Blob.datakey) }
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
