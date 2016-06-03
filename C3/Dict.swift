//
//  Dict.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import Foundation
import CoreData
public class Dict: NSManagedObject {
	@NSManaged public var key: AnyObject
	@NSManaged public var value: AnyObject
}
extension Context {
	public func newDict()->Dict? {
		return new()
	}
	public func searchDict( let attribute: [String: AnyObject] = [:] ) -> [Dict] {
		return fetch(attribute)
	}
}