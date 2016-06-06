//
//  Cell.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import Accelerate
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
		var bias: Buffer = Buffer()
		var stage: Buffer = Buffer()
		var noise: Buffer = Buffer()
		var value: Buffer = Buffer()
		var lucky: Buffer = Buffer()
		var state: Buffer = Buffer()
		var error: Buffer = Buffer()
		var delta: Buffer = Buffer()
	}
	private let buf: MTLRef = MTLRef()
}
extension Cell: Network {
	public func clear ( ) {
		if let context: Context = managedObjectContext as? Context, cmd: MTLCommandBuffer = context.newMTLCommandBuffer() {
			let blit: MTLBlitCommandEncoder = cmd.blitCommandEncoder()
			for buffer in [ buf.stage, buf.value, buf.error ] {
				if let buffer: MTLBuffer = buffer.mtl {
					blit.fillBuffer(buffer, range: NSRange(location: 0, length: buffer.length), value: 0)
				}
			}
			blit.endEncoding()
			if let buffer: MTLBuffer = buf.noise.mtl {
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
		if let context: Context = managedObjectContext as? Context, cmd: MTLCommandBuffer = context.newMTLCommandBuffer() {
			cmd.addCompletedHandler {(_)in
				vDSP_vsub(
					UnsafePointer<Float>(destination.map{Float($0)}), 1,
					self.buf.state.scalar.baseAddress, 1,
					self.buf.error.scalar.baseAddress, 1,
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
		if let context: Context = managedObjectContext as? Context, cmd: MTLCommandBuffer = context.newMTLCommandBuffer() {
			cmd.addCompletedHandler {(_)in
				NSData(bytesNoCopy: UnsafeMutablePointer(buffer.map{Float($0)}), length: sizeof(Float)*buffer.count, freeWhenDone: false).getBytes(UnsafeMutablePointer<Void>(self.buf.state.raw.bytes), length: self.buf.state.raw.length)
			}
			cmd.commit()
		} else {
			NSData(bytesNoCopy: UnsafeMutablePointer(buffer.map{Float($0)}), length: sizeof(Float)*buffer.count, freeWhenDone: false).getBytes(UnsafeMutablePointer<Void>(buf.state.raw.bytes), length: buf.state.raw.length)
		}
	}
	public func getState ( let callback fun: ([Bool]->Void) ) {
		if let context: Context = managedObjectContext as? Context, cmd: MTLCommandBuffer = context.newMTLCommandBuffer() {
			cmd.addCompletedHandler {(_)in
				fun(self.buf.state.scalar.map{Bool($0)})
			}
			cmd.commit()
		} else {
			fun(buf.state.scalar.map{Bool($0)})
		}
	}
	public var state: [Bool] {
		get {
			var result: [Float] = [Float](count: width, repeatedValue: 0.0)
			if let context: Context = managedObjectContext as? Context, cmd: MTLCommandBuffer = context.newMTLCommandBuffer() {
				cmd.addCompletedHandler {(_)in
					self.buf.state.raw.getBytes(&result, length: sizeof(Float)*result.count)
				}
				cmd.commit()
				cmd.waitUntilCompleted()
			} else {
				buf.state.raw.getBytes(&result, length: sizeof(Float)*result.count)
			}
			return result.map{Bool($0)}
		}
		set {
			setState(newValue: newValue)
		}
	}
	public func setValue ( let newValue buffer: [Float] ) {
		if let cmd: MTLCommandBuffer = (managedObjectContext as? Context)?.newMTLCommandBuffer() {
			cmd.addCompletedHandler {(_)in
				NSData(bytesNoCopy: UnsafeMutablePointer(buffer), length: sizeof(Float)*buffer.count, freeWhenDone: false).getBytes(UnsafeMutablePointer<Void>(self.buf.value.raw.bytes), length: self.buf.value.raw.length)
			}
			cmd.commit()
		} else {
			NSData(bytesNoCopy: UnsafeMutablePointer(buffer), length: sizeof(Float)*buffer.count, freeWhenDone: false).getBytes(UnsafeMutablePointer<Void>(buf.value.raw.bytes), length: buf.value.raw.length)
		}
	}
	public func getValue ( let callback fun: ([Float] -> Void) ) {
		if let cmd: MTLCommandBuffer = (managedObjectContext as? Context)?.newMTLCommandBuffer() {
			cmd.addCompletedHandler {(_)in
				fun(Array<Float>(self.buf.value.scalar))
			}
			cmd.commit()
		} else {
			fun(Array<Float>(buf.value.scalar))
		}
	}
}
extension Cell: CoreDataSharedMetal {
	func setup () {
		if let context: Context = managedObjectContext as? Context {
			buf.bias = context.newBuffer(data: bias)
			buf.stage = context.newBuffer(length: sizeof(UInt8))
			buf.noise = context.newBuffer(length: sizeof(UInt8)*width)
			buf.value = context.newBuffer(length: sizeof(Float)*width)
			buf.lucky = context.newBuffer(length: sizeof(Float)*width)
			buf.state = context.newBuffer(length: sizeof(Float)*width)
			buf.error = context.newBuffer(length: sizeof(Float)*width)
			buf.delta = context.newBuffer(length: sizeof(Float)*width)
			
			bias = buf.bias.raw
		}
	}
	public override func awakeFromInsert() {
		super.awakeFromInsert()
		attribute = [:]
	}
	public override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
	public override func awakeFromSnapshotEvents(flags: NSSnapshotEventType) {
		super.awakeFromSnapshotEvents(flags)
		setup()
	}
	public override func awakeAfterUsingCoder(aDecoder: NSCoder) -> AnyObject? {
		let result: AnyObject? = super.awakeAfterUsingCoder(aDecoder)
		setup()
		return result
	}
}
extension Context {
	public func newCell ( let width size: Int, let label: String = "", let recur: Bool = false, let input: [Cell] = [] ) -> Cell? {
		let cell: Cell? = new()
		let width: Int = max( size + 0x0f - ( ( size + 0x0f ) % 0x10 ), 0x10 )
		if let cell: Cell = cell {
			cell.width = width
			cell.label = label
			cell.recur = recur
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
