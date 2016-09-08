//
//  ManagedObject.swift
//  C³
//
//  Created by Kota Nakano on 9/8/16.
//
//
import CoreData

internal typealias ManagedObject = NSManagedObject
internal typealias SnapshotEventType = NSSnapshotEventType
extension ManagedObject {
	var context: Context {
		return managedObjectContext as! Context
	}
}