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
	class Buffers {
		var gain: Buffer = Buffer()
	}
	let buf: Buffers = Buffers()
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
			buf.gain = Buffer(mtl: context.newMTLBuffer(data: gain))
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
