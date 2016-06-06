//
//  Edge.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import Accelerate
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
			let mtlgain: MTLBuffer = context.newMTLBuffer(data: gain)
			gain = NSData(bytesNoCopy: mtlgain.contents(), length: mtlgain.length, freeWhenDone: false)
			mtl.gain = mtlgain
		}
	}
	override func awakeFromInsert() {
		super.awakeFromInsert()
	}
	override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
	override func awakeFromSnapshotEvents(flags: NSSnapshotEventType) {
		super.awakeFromSnapshotEvents(flags)
		setup()
	}
	override func awakeAfterUsingCoder(aDecoder: NSCoder) -> AnyObject? {
		let result: AnyObject? = super.awakeAfterUsingCoder(aDecoder)
		setup()
		return result
	}
}
