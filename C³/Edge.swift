//
//  Edge.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import CoreData
import Metal

class Edge: NSManagedObject {
	@NSManaged var gain: NSData
	@NSManaged var input: Cell
	@NSManaged var output: Cell
	class MTLRef {
		var gain: MTLBuffer?
	}
	let mtl: MTLRef = MTLRef()
}
extension Edge {
	override func awakeFromFetch() {
		
	}
}
extension Edge: Network {
	func clear ( ) {
		input.clear()
	}
	func chain ( let callback: ( Cell -> Void ) ) {
		input.chain( callback )
	}
	func train ( let eps: Float ) {
		input.train( eps )
	}
}
extension Edge: CoreDataSharedMetal {
	func setup() {
		if let context: Context = managedObjectContext as? Context {
			let mtlgain: MTLBuffer = context.allocate(data: gain)
			gain = NSData(bytesNoCopy: mtlgain.contents(), length: mtlgain.length, freeWhenDone: false)
			mtl.gain = mtlgain
		}
	}
}
