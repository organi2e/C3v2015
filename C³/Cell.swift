//
//  Cell.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import CoreData
import Metal

public class Cell: NSManagedObject {
	
	@NSManaged public private(set) var label: String
	@NSManaged public private(set) var width: Int
	@NSManaged public private(set) var recur: Bool
	@NSManaged public var attribute: [String: AnyObject]
	@NSManaged private var bias: NSData
	@NSManaged private var input: Set<Edge>
	@NSManaged private var output: Set<Edge>
	
	private class MTLRef {
		var bias: MTLBuffer?
		var stage: MTLBuffer?
		var noise: MTLBuffer?
		var value: MTLBuffer?
		var lucky: MTLBuffer?
		var state: MTLBuffer?
		var delta: MTLBuffer?
	}
	private let mtl: MTLRef = MTLRef()
}
extension Cell: Network {
	public func clear ( ) {
		let cmd: MTLCommandBuffer = context.newMTLCommandBuffer()
		let blit: MTLBlitCommandEncoder = cmd.blitCommandEncoder()
		for buffer in [mtl.value, mtl.delta ] {
			if let buffer: MTLBuffer = buffer {
				blit.fillBuffer(buffer, range: NSRange(location: 0, length: buffer.length), value: 0)
			}
		}
		blit.endEncoding()
		cmd.addCompletedHandler {(_)in
			if let buffer: MTLBuffer = self.mtl.noise {
				self.context.entropy(buffer)
			}
		}
		cmd.commit()
		input.forEach {
			$0.clear()
		}
	}
	public func chain ( let callback: ( Cell -> Void ) ) {
		callback(self)
		input.forEach {
			$0.chain(callback)
		}
	}
	public func correct ( let destination: [Bool], let eps: Float ) {
	
	}
	func train ( let eps: Float ) {
	
	}
	public var terminus: Bool {
		get {
			return input.isEmpty
		}
	}
}
extension Cell: CoreDataSharedMetal {
	func setup () {
		let mtlbias: MTLBuffer = context.allocate(data: bias)
		bias = NSData(bytesNoCopy: mtlbias.contents(), length: mtlbias.length, freeWhenDone: false)
		mtl.bias = mtlbias
		mtl.stage = context.allocate(length: sizeof(UInt8))
		mtl.noise = context.allocate(length: sizeof(UInt8)*width)
		mtl.value = context.allocate(length: sizeof(Float)*width)
		mtl.lucky = context.allocate(length: sizeof(Float)*width)
		mtl.state = context.allocate(length: sizeof(Float)*width)
		mtl.delta = context.allocate(length: sizeof(Float)*width)
	}
}
extension Context {
	public func newCell ( let width width: Int, let label: String = "", let recur: Bool = false, let input: [Cell] = [] ) -> Cell? {
		let cell: Cell? = new()
		if let cell: Cell = cell {
			cell.width = width
			cell.label = label
			cell.recur = recur
			cell.attribute = [:]
			cell.bias = NSData(bytes: [Float](count: width, repeatedValue: 0.0), length: sizeof(Float)*width)
			cell.setup()
			
			input.forEach { ( let input: Cell ) in
				if input.managedObjectContext === self, let edge: Edge = new() {
					edge.input = input
					edge.gain = NSData(bytes: [Float](count: cell.width*input.width, repeatedValue: 0.0), length: sizeof(Float)*cell.width*input.width)
					edge.setup()
					cell.input.insert(edge)
				}
			}
		}
		return cell
	}
	public func searchCell( let width width: Int? = nil, let label: String? = nil ) -> [Cell] {
		var attribute: [String: AnyObject] = [:]
		if let width: Int = width {
			attribute [ "width" ] = width
		}
		if let label: String = label {
			attribute [ "label" ] = label
		}
		let cell: [Cell] = fetch ( attribute )
		return cell
	}
}
