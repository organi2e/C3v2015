//
//  Cell.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import CoreData
import Accelerate
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
		var error: MTLBuffer?
		var delta: MTLBuffer?
	}
	private let mtl: MTLRef = MTLRef()
}
extension Cell: Network {
	public func clear ( ) {
		if let context: Context = managedObjectContext as? Context {
			let cmd: MTLCommandBuffer = context.newMTLCommandBuffer()
			let blit: MTLBlitCommandEncoder = cmd.blitCommandEncoder()
			for buffer in [ mtl.stage, mtl.value, mtl.error ] {
				if let buffer: MTLBuffer = buffer {
					blit.fillBuffer(buffer, range: NSRange(location: 0, length: buffer.length), value: 0)
				}
			}
			blit.endEncoding()
			if let buffer: MTLBuffer = mtl.noise {
				cmd.addCompletedHandler {(_)in
					context.entropy(buffer)
				}
			}
			cmd.commit()
			input.forEach {
				$0.clear()
			}
		}
	}
	public func chain ( let callback: ( Cell -> Void ) ) {
		callback(self)
		input.forEach {
			$0.chain(callback)
		}
	}
	public func correct ( let destination: [Bool], let eps: Float ) {
		if let context: Context = managedObjectContext as? Context, state: MTLBuffer = mtl.state, delta: MTLBuffer = mtl.delta {
			let cmd: MTLCommandBuffer = context.newMTLCommandBuffer()
			cmd.addCompletedHandler {(_)in
				vDSP_vsub(
					UnsafePointer<Float>(destination.map{Float($0)}), 1,
					UnsafePointer<Float>(state.contents()), 1,
					UnsafeMutablePointer<Float>(delta.contents()), 1,
					UInt(self.width)
				)
			}
			cmd.commit()
		}
	}
	func train ( let eps: Float ) {
	
	}
	public var terminus: Bool {
		get {
			return input.isEmpty
		}
	}
}
extension Cell {
	public func setState ( let newValue buffer: [Bool] ) {
		if let context: Context = managedObjectContext as? Context, target: MTLBuffer = mtl.state {
			let cmd: MTLCommandBuffer = context.newMTLCommandBuffer()
			cmd.addCompletedHandler {(_)in
				NSData(bytesNoCopy: UnsafeMutablePointer(buffer.map{Float($0)}), length: sizeof(Float)*buffer.count, freeWhenDone: false).getBytes(target.contents(), length: target.length)
			}
			cmd.commit()
		}
	}
	public func getState ( let callback fun: ([Bool]->Void) ) {
		if let context: Context = managedObjectContext as? Context, source: MTLBuffer = mtl.state {
			let cmd: MTLCommandBuffer = context.newMTLCommandBuffer()
			cmd.addCompletedHandler {(_)in
				fun(UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(source.contents()), count: source.length/sizeof(Float)).map{Bool($0)})
			}
			cmd.commit()
		}
	}
	
	public var state: [Bool] {
		get {
			var result: [Float] = [Float](count: width, repeatedValue: 0.0)
			if let
				context: Context = managedObjectContext as? Context,
				buffer: MTLBuffer = mtl.state
			{
				let cmd: MTLCommandBuffer = context.newMTLCommandBuffer()
				cmd.addCompletedHandler {(_)in
					NSData(bytesNoCopy: buffer.contents(), length: buffer.length, freeWhenDone: false).getBytes(&result, length: sizeof(Float)*result.count)
				}
				cmd.commit()
				cmd.waitUntilCompleted()
			}
			return result.map{Bool($0)}
		}
		set {
			setState(newValue: newValue)
		}
	}
	public func setValue ( let newValue buffer: [Float] ) {
		if let context: Context = managedObjectContext as? Context, target: MTLBuffer = mtl.value {
			let cmd: MTLCommandBuffer = context.newMTLCommandBuffer()
			cmd.addCompletedHandler {(_)in
				NSData(bytesNoCopy: UnsafeMutablePointer(buffer), length: sizeof(Float)*buffer.count, freeWhenDone: false).getBytes(target.contents(), length: target.length)
			}
			cmd.commit()
		}
	}
	public func getValue ( let callback fun: ([Float]->Void) ) {
		if let context: Context = managedObjectContext as? Context, source: MTLBuffer = mtl.value {
			let cmd: MTLCommandBuffer = context.newMTLCommandBuffer()
			cmd.addCompletedHandler {(_)in
				fun(Array<Float>(UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(source.contents()), count: source.length/sizeof(Float))))
			}
			cmd.commit()
		}
	}

}
extension Cell: CoreDataSharedMetal {
	func setup () {
		if let context: Context = managedObjectContext as? Context {
			let mtlbias: MTLBuffer = context.newMTLBuffer(data: bias)
			bias = NSData(bytesNoCopy: mtlbias.contents(), length: mtlbias.length, freeWhenDone: false)
			mtl.bias = mtlbias
			mtl.stage = context.newMTLBuffer(length: sizeof(UInt8))
			mtl.noise = context.newMTLBuffer(length: sizeof(UInt8)*width)
			mtl.value = context.newMTLBuffer(length: sizeof(Float)*width)
			mtl.lucky = context.newMTLBuffer(length: sizeof(Float)*width)
			mtl.state = context.newMTLBuffer(length: sizeof(Float)*width)
			mtl.error = context.newMTLBuffer(length: sizeof(Float)*width)
			mtl.delta = context.newMTLBuffer(length: sizeof(Float)*width)
		}
	}
}
extension Context {
	public func newCell ( let width width: Int, let label: String = "", let recur: Bool = false, let input: [Cell] = [] ) -> Cell? {
		let cell: Cell? = new()
		if let cell: Cell = cell {
			cell.width = width + 3 - ( ( width + 3 ) % 4 )
			cell.label = label
			cell.recur = recur
			cell.attribute = [:]
			cell.bias = NSData(bytes: [Float](count: width, repeatedValue: 0.0), length: sizeof(Float)*width)
			cell.setup()
			
			input.forEach { ( let input: Cell ) in
				if input.managedObjectContext === self, let edge: Edge = new() {
					edge.input = input
					edge.output = cell
					edge.gain = NSData(bytes: [Float](count: cell.width*input.width, repeatedValue: 0.0), length: sizeof(Float)*cell.width*input.width)
					edge.setup()
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
