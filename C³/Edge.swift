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
	var A: LA = LA(row: 1, col: 1)
}
extension Edge {
	@NSManaged var mean: NSData
	@NSManaged var variance: NSData
	@NSManaged var input: Cell
	@NSManaged var output: Cell
}
extension Edge {
	func setup() {
		let M: Int = output.width
		let N: Int = input.width
		A = LA(row: M, col: N)
	}
	override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
	override func awakeFromSnapshotEvents(flags: NSSnapshotEventType) {
		super.awakeFromSnapshotEvents(flags)
		setup()
	}
}