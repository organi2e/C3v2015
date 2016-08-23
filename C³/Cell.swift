//
//  Cell.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import Accelerate
import Metal
import CoreData

public class Cell: NSManagedObject {
	
	private enum Ready {
		case ψ
		case ϰ
		case δ
	}
	private var ready: Set<Ready> = Set<Ready>()
	
	private struct Deterministic {
		let ψ: MTLBuffer
		let ϰ: MTLBuffer
		let δ: MTLBuffer
	}
	
	private struct Probabilistic {
		let χ: MTLBuffer
		let μ: MTLBuffer
		let σ: MTLBuffer
	}
	
	private var Υ: RingBuffer<Deterministic> = RingBuffer<Deterministic>(array: [])
	private var Φ: RingBuffer<Probabilistic> = RingBuffer<Probabilistic>(array: [])
	private var Δ: RingBuffer<Probabilistic> = RingBuffer<Probabilistic>(array: [])
	
}

extension Cell {
	@NSManaged public private(set) var label: String
	@NSManaged public private(set) var width: Int
	@NSManaged public private(set) var attribute: [String: AnyObject]
	@NSManaged private var input: Set<Edge>
	@NSManaged private var output: Set<Edge>
	@NSManaged private var bias: Bias
	@NSManaged private var feedback: Feedback?
	@NSManaged private var decay: Decay?
}

extension Cell {
	public override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
	public override func awakeFromSnapshotEvents(flags: NSSnapshotEventType) {
		super.awakeFromSnapshotEvents(flags)
		setup()
	}
}

extension Cell {
	public var withDecay: Bool {
		return decay != nil
	}
	public var withFeedback: Bool {
		return feedback != nil
	}
}

extension Cell {
	internal func setup() {
		
		if let context: Context = managedObjectContext as? Context {
			
			let count: Int = 2
			
			Υ = RingBuffer<Deterministic>(array: (0..<count).map{(_)in
				return Deterministic(
					ψ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
					ϰ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
					δ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
				)
			})
			Φ = RingBuffer<Probabilistic>(array: (0..<count).map{(_)in
				return Probabilistic(
					χ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
					μ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
					σ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
				)
			})
			Δ = RingBuffer<Probabilistic>(array: (0..<count).map{(_)in
				return Probabilistic(
					χ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
					μ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate),
					σ: context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
				)
			})
		
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		
		}
		iRefresh()
		oRefresh()
	}
}
extension Cell {
	internal func iRefresh() {
		
		if let context: Context = managedObjectContext as? Context where 0 < width {
			
			Υ.progress()
			
			let ψ: MTLBuffer = Υ.new.ψ
			let ϰ: MTLBuffer = Υ.new.ϰ
			let δ: MTLBuffer = Υ.new.δ
			
			Φ.progress()
			
			let χ: MTLBuffer = Φ.new.χ
			let μ: MTLBuffer = Φ.new.μ
			let σ: MTLBuffer = Φ.new.σ

			context.newBlitCommand {
				
				$0.fillBuffer(ψ, range: NSRange(location: 0, length: ψ.length), value: 0)
				$0.fillBuffer(ϰ, range: NSRange(location: 0, length: ϰ.length), value: 0)
				$0.fillBuffer(δ, range: NSRange(location: 0, length: δ.length), value: 0)
				
				$0.fillBuffer(χ, range: NSRange(location: 0, length: χ.length), value: 0)
				$0.fillBuffer(μ, range: NSRange(location: 0, length: μ.length), value: 0)
				$0.fillBuffer(σ, range: NSRange(location: 0, length: σ.length), value: 0)
				
			}
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		
		}
		bias.refresh()
	}
	private func oRefresh() {
		
		if let context: Context = managedObjectContext as? Context where 0 < width {
			
			Δ.progress()
			
			let χ: MTLBuffer = Δ.new.χ
			let μ: MTLBuffer = Δ.new.μ
			let σ: MTLBuffer = Δ.new.σ
			
			context.newBlitCommand {
				$0.fillBuffer(χ, range: NSRange(location: 0, length: χ.length), value: 0)
				$0.fillBuffer(μ, range: NSRange(location: 0, length: μ.length), value: 0)
				$0.fillBuffer(σ, range: NSRange(location: 0, length: σ.length), value: 0)
			}
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		
		}
	}
	
	public func iClear(let ignore: Set<Cell>=[]) {
		if ignore.contains(self) {
			
		} else if ready.contains(.ϰ) {
			input.forEach {
				$0.shuffle()
				$0.input.iClear(ignore.union([self]))
			}
			iRefresh()
			ready.remove(.ϰ)
		}
	}
	public func oClear(let ignore: Set<Cell>=[]) {
		if ignore.contains(self) {
		
		} else if ready.contains(.δ) {
			output.forEach {
				$0.refresh()
				$0.output.oClear(ignore.union([self]))
			}
			oRefresh()
			ready.remove(.δ)
		}
		ready.remove(.ψ)
	}
	
	public func collect(let visit visit: Set<Cell>=[]) -> MTLBuffer {
		
		if visit.contains(self) {
			return Υ.old.ϰ
			
		} else {
			
			if ready.contains(.ϰ) {
				return Υ.new.ϰ
				
			} else if let context: Context = managedObjectContext as? Context {
				
				input.forEach {
					$0.collect(Φ: (Φ.new.χ, Φ.new.μ, Φ.new.σ), visit: visit.union([self]))
				}
				bias.collect(level: (Φ.new.χ, Φ.new.μ, Φ.new.σ))
				self.dynamicType.activate(context: context,
				                          Υ: Υ.new.ϰ,
				                          Φ: Φ.new.χ,
				                          width: width)
				ready.insert(.ϰ)
				
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
		}
		return Υ.new.ϰ
	}
	public func correct(let η η: Float, let visit: Set<Cell>=[]) -> (MTLBuffer, MTLBuffer, MTLBuffer) {
		if visit.contains(self) {
			return(Δ.old.χ, Δ.old.μ, Δ.old.σ)
			
		} else {
			if ready.contains(.δ) {
				return(Δ.new.χ, Δ.new.μ, Δ.new.σ)
				
			} else if ready.contains(.ϰ) {
				if let context: Context = managedObjectContext as? Context {

					if ready.contains(.ψ) {
						self.dynamicType.difference(context: context,
						                            δ: Υ.new.δ,
						                            ψ: Υ.new.ψ,
						                            ϰ: Υ.new.ϰ,
						                            width: width)
					
					} else {
						output.forEach {
							$0.correct(δ: Υ.new.δ, η: η, ϰ: Υ.new.ϰ, visit: visit.union([self]))
						}
						
					}
					self.dynamicType.derivate(context: context,
					                          Δ: (Δ.new.χ, Δ.new.μ, Δ.new.σ),
					                          Φ: (Φ.new.χ, Φ.new.μ, Φ.new.σ),
					                          δ: Υ.new.δ,
					                          width: width)
					bias.correct(η: η, Δ: (Δ.new.μ, Δ.new.σ))
					ready.insert(.δ)
					
				} else {
					assertionFailure(Context.Error.InvalidContext.rawValue)
					
				}
			}
		}
		return(Δ.new.χ, Δ.new.μ, Δ.new.σ)
	}
}
extension Cell {
	public var active: [Bool] {
		set {
			if let context: Context = managedObjectContext as? Context {
				let cache: MTLBuffer = context.newBuffer((0..<width).map{$0<newValue.count ? newValue[$0] ? 1:0:0}, options: .StorageModePrivate)
				let value: MTLBuffer = Υ.new.ϰ
				let size: Int = sizeof(Float) * width
				
				assert(size==cache.length)
				assert(size==value.length)
				
				context.newBlitCommand(complete: { cache.setPurgeableState(.Empty) }) {
					$0.copyFromBuffer(cache, sourceOffset: 0, toBuffer: value, destinationOffset: 0, size: size)
				}
				ready.insert(.ϰ)
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
		}
		get {
			collect()
			if let context: Context = managedObjectContext as? Context {
				let cache: MTLBuffer = context.newBuffer(length: sizeof(Float)*width, options: .CPUCacheModeDefaultCache)
				let value: MTLBuffer = Υ.new.ϰ
				let size: Int = sizeof(Float) * width
				
				assert(size==cache.length)
				assert(size==value.length)
				
				context.newBlitCommand(sync: true) {
					$0.copyFromBuffer(value, sourceOffset: 0, toBuffer: cache, destinationOffset: 0, size: size)
				}
				UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(cache.contents()), count: width).forEach {
					assert(!isnan($0))
					assert(!isinf($0))
				}
				defer { cache.setPurgeableState(.Empty) }
				return UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(cache.contents()), count: width).map{Bool($0)}
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
			return [Bool](count: width, repeatedValue: false)
		}
	}
	public var answer: [Bool] {
		set {
			if let context: Context = managedObjectContext as? Context {
				let cache: MTLBuffer = context.newBuffer((0..<width).map{$0<newValue.count ? newValue[$0] ? 1:0:0}, options: .StorageModePrivate)
				let train: MTLBuffer = Υ.new.ψ
				let size: Int = sizeof(Float) * width
				
				assert(size==cache.length)
				assert(size==train.length)
				
				context.newBlitCommand(complete: { cache.setPurgeableState(.Empty) }) {
					$0.copyFromBuffer(cache, sourceOffset: 0, toBuffer: train, destinationOffset: 0, size: size)
				}
				ready.insert(.ψ)
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
		}
		get {
			if let context: Context = managedObjectContext as? Context {
				let cache: MTLBuffer = context.newBuffer(length: sizeof(Float)*width, options: .CPUCacheModeDefaultCache)
				let train: MTLBuffer = Υ.new.ψ
				let size: Int = sizeof(Float) * width
				
				assert(size==cache.length)
				assert(size==train.length)
				
				context.newBlitCommand(sync: true) {
					$0.copyFromBuffer(train, sourceOffset: 0, toBuffer: cache, destinationOffset: 0, size: size)
				}
				UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(cache.contents()), count: width).forEach {
					assert(!isnan($0))
					assert(!isinf($0))
				}
				defer { cache.setPurgeableState(.Empty) }
				return UnsafeMutableBufferPointer<Float>(start: UnsafeMutablePointer<Float>(cache.contents()), count: width).map{Bool($0)}
			} else {
				assertionFailure(Context.Error.InvalidContext.rawValue)
				
			}
			return [Bool](count: width, repeatedValue: false)
		}
	}
	public var isRecurrent: Bool {
		return feedback != nil || decay != nil
	}
}
extension Cell {
	internal class var differenceKernel: String { return "cellDifference" }
	internal class var activateKernel: String { return "cellActivate" }
	internal class var derivateKernel: String { return "cellDerivate" }
	internal static func difference(let context context: Context, let δ: MTLBuffer, let ψ: MTLBuffer, let ϰ: MTLBuffer, let width: Int) {
		context.newComputeCommand(function: differenceKernel) {
			$0.setBuffer(δ, offset: 0, atIndex: 0)
			$0.setBuffer(ψ, offset: 0, atIndex: 1)
			$0.setBuffer(ϰ, offset: 0, atIndex: 2)
			$0.dispatchThreadgroups(MTLSize(width: width/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func activate(let context context: Context, let Υ: MTLBuffer, let Φ: MTLBuffer, let width: Int) {
		context.newComputeCommand(function: activateKernel) {
			$0.setBuffer(Υ, offset: 0, atIndex: 0)
			$0.setBuffer(Φ, offset: 0, atIndex: 1)
			$0.dispatchThreadgroups(MTLSize(width: width/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func derivate(let context context: Context, let Δ: (MTLBuffer, MTLBuffer, MTLBuffer), let Φ: (MTLBuffer, MTLBuffer, MTLBuffer), let δ: MTLBuffer, let width: Int) {
		context.newComputeCommand(function: derivateKernel) {
			$0.setBuffer(Δ.0, offset: 0, atIndex: 0)
			$0.setBuffer(Δ.1, offset: 0, atIndex: 1)
			$0.setBuffer(Δ.2, offset: 0, atIndex: 2)
			$0.setBuffer(Φ.0, offset: 0, atIndex: 3)
			$0.setBuffer(Φ.1, offset: 0, atIndex: 4)
			$0.setBuffer(Φ.2, offset: 0, atIndex: 5)
			$0.setBuffer(δ, offset: 0, atIndex: 6)
			$0.setBytes([Float(M_PI)], length: sizeof(Float), atIndex: 7)
			$0.dispatchThreadgroups(MTLSize(width: width/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func forget(let context context: Context, let error: MTLBuffer, let λ: Float, let width: Int) {
		context.newComputeCommand(function: "cellForget") {
			$0.setBuffer(error, offset: 0, atIndex: 0)
			$0.setBytes([λ], length: sizeof(Float), atIndex: 1)
			$0.dispatchThreadgroups(MTLSize(width: width/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
}
extension Context {
	public func newCell ( let width width: Int, let label: String = "", let recur: Bool = false, let buffer: Bool = false, let input: [Cell] = [] ) throws -> Cell {
		guard let cell: Cell = new() else {
			throw Error.CoreData.InsertionFails(entity: Cell.className())
		}
		cell.label = label
		cell.width = ((width-1)/4+1)*4
		cell.attribute = [:]
		cell.input = Set<Edge>()
		cell.output = Set<Edge>()
		cell.setup()
		try input.forEach {
			try newEdge(output: cell, input: $0)
		}
		try newBias(output: cell)
		return cell
	}
	public func searchCell( let width width: Int? = nil, let label: String? = nil ) -> [Cell] {
		var attribute: [String: AnyObject] = [:]
		if let width: Int = width {
			attribute [ "width" ] = ((width-1)/4+1)*4
		}
		if let label: String = label {
			attribute [ "label" ] = label
		}
		return fetch ( attribute )
	}
	public func chainCell(let output output: Cell, let input: Cell) throws {
		let contains: Bool = output.input.map { $0 === input } .reduce(false) { $0.0 || $0.1 }
		if !contains {
			try newEdge(output: output, input: input)
		}
	}
	public func unchainCell(let output output: Cell, let input: Cell) {
		output.input.filter{ $0.input === input }.forEach {
			deleteObject($0)
		}
	}
}