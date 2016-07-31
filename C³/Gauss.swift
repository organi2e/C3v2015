//
//  Gauss.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import CoreData
internal class Gauss: NSManagedObject {

}
extension Gauss {
	@NSManaged private var mean: NSData
	@NSManaged private var logvariance: NSData
	@NSManaged private var alter: Alter
}
extension Gauss {

}