//
//  Edge.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import CoreData
import Metal

internal class Edge: NSManagedObject {
	@NSManaged var gain: NSData
	@NSManaged var input: Cell
	@NSManaged var output: Cell
}
internal extension Edge {
	internal func allocate() {
	
	}
	override func awakeFromFetch() {
		
	}
}