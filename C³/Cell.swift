//
//  Cell.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import Accelerate
import CoreData
import simd
public class Cell: NSManagedObject {
	
	private enum Ready {
		case ψ
		case κ
		case δ
	}
	
	private var ready: Set<Ready> = Set<Ready>()
	private var state: RingBuffer<(ψ: [Float], κ: [Float], δ: [Float])> = RingBuffer<(ψ: [Float], κ: [Float], δ: [Float])>(array: [])
	private var level: RingBuffer<(χ: [Float], μ: [Float], λ: [Float])> = RingBuffer<(χ: [Float], μ: [Float], λ: [Float])>(array: [])
	private var delta: RingBuffer<(χ: [Float], μ: [Float], σ: [Float])> = RingBuffer<(χ: [Float], μ: [Float], σ: [Float])>(array: [])
	
}

extension Cell {
	@NSManaged public private(set) var label: String
	@NSManaged public private(set) var width: Int
	@NSManaged public private(set) var attribute: [String: AnyObject]
	@NSManaged public var priority: Int
	@NSManaged public var distributionType: String
	@NSManaged private var input: Set<Edge>
	@NSManaged private var output: Set<Edge>
	@NSManaged private var bias: Bias
	@NSManaged private var circular: Circular?
	@NSManaged private var decay: Decay?
}
extension Cell {
	public var type: DistributionType {
		get {
			return DistributionType(rawValue: distributionType) ?? .False
		}
		set {
			distributionType = newValue.rawValue
		}
	}
	internal var distribution: Distribution.Type {
		switch type {
		case .Gauss: return GaussianDistribution.self
		case .Cauchy: return CauchyDistribution.self
		case .False: return FalseDistribution.self
		}
	}
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
//	public var withFeedback: Bool {
//		return feedback != nil
//	}
}

extension Cell {
	internal func setup() {
		let count: Int = 2
		state = RingBuffer<(ψ: [Float], κ: [Float], δ: [Float])>(array: (0..<count).map{(_)in
			(
				ψ: [Float](count: width, repeatedValue: 0),
				κ: [Float](count: width, repeatedValue: 0),
				δ: [Float](count: width, repeatedValue: 0)
			)
		})
		level = RingBuffer<(χ: [Float], μ: [Float], λ: [Float])>(array: (0..<count).map{(_)in
			(
				χ: [Float](count: width, repeatedValue: 0),
				μ: [Float](count: width, repeatedValue: 0),
				λ: [Float](count: width, repeatedValue: 0)
			)
		})
		delta = RingBuffer<(χ: [Float], μ: [Float], σ: [Float])>(array: (0..<count).map{(_)in
			(
				χ: [Float](count: width, repeatedValue: 0),
				μ: [Float](count: width, repeatedValue: 0),
				σ: [Float](count: width, repeatedValue: 0)
			)
		})
	}
}
extension Cell {
	public func collect_clear() {
		if ready.contains(.κ) {
			ready.remove(.κ)
			input.forEach {
				$0.collect_clear()
			}
			bias.collect_clear()
			state.progress()
			level.progress()
		}
	}
	public func correct_clear() {
		if ready.contains(.δ) {
			ready.remove(.δ)
			output.forEach {
				$0.correct_clear()
			}
			bias.correct_clear()
			delta.progress()
		}
		ready.remove(.ψ)
	}
	public func collect(ignore: Set<Cell> = []) -> LaObjet {
		if ignore.contains(self) {
			return _κ
		} else {
			if !ready.contains(.κ) {
				let refer: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)] = input.map { $0.collect(ignore.union([self])) } + [ bias.collect() ]
				distribution.synthesize(χ: UnsafeMutablePointer<Float>(level.new.χ), μ: UnsafeMutablePointer<Float>(level.new.μ), λ: UnsafeMutablePointer<Float>(level.new.λ), refer: refer, count: width)
				distribution.activate(UnsafeMutablePointer<Float>(state.new.κ), φ: level.new.χ, count: width)
				ready.insert(.κ)
			}
			return κ
		}
	}
	public func correct(ignore: Set<Cell> = []) -> (LaObjet, LaObjet, LaObjet) {
		if ignore.contains(self) {
			return (_Δχ, _Δμ, _Δσ)
		} else {
			if !ready.contains(.δ) {
				if ready.contains(.ψ) {
					let ψ: LaObjet = LaMatrice(state.new.ψ, rows: width, cols: 1, deallocator: nil)
					let κ: LaObjet = LaMatrice(state.new.κ, rows: width, cols: 1, deallocator: nil)
					let δ: LaObjet = κ - ψ
					δ.getBytes(state.new.δ)
				} else {
					let δ: LaObjet = output.map { $0.correct(ignore.union([self])) } .reduce(LaValuer(0)) { $0.0 + $0.1 }
					δ.getBytes(state.new.δ)
				}
				distribution.derivate((χ: UnsafeMutablePointer<Float>(delta.new.χ), μ: UnsafeMutablePointer<Float>(delta.new.μ), σ: UnsafeMutablePointer<Float>(delta.new.σ)), δ: state.new.δ, μ: level.new.μ, λ: level.new.λ, count: width)
				ready.insert(.δ)
				bias.update(distribution,
					Δμ: Δμ,
					Δσ: Δσ
				)
			}
			return (Δχ, Δμ, Δσ)
		}
	}
}
extension Cell {
	
	private var κ: LaObjet { return LaMatrice(state.new.κ, rows: width, cols: 1, deallocator: nil) }
	private var δ: LaObjet { return LaMatrice(state.new.δ, rows: width, cols: 1, deallocator: nil) }
	
	private var _κ: LaObjet { return LaMatrice(state.old.κ, rows: width, cols: 1, deallocator: nil) }
	private var _δ: LaObjet { return LaMatrice(state.old.δ, rows: width, cols: 1, deallocator: nil) }
	
	private var χ: LaObjet { return LaMatrice(level.new.χ, rows: width, cols: 1, deallocator: nil) }
	private var μ: LaObjet { return LaMatrice(level.new.μ, rows: width, cols: 1, deallocator: nil) }
	private var λ: LaObjet { return LaMatrice(level.new.λ, rows: width, cols: 1, deallocator: nil) }
	
	private var _χ: LaObjet { return LaMatrice(level.old.χ, rows: width, cols: 1, deallocator: nil) }
	private var _μ: LaObjet { return LaMatrice(level.old.μ, rows: width, cols: 1, deallocator: nil) }
	private var _λ: LaObjet { return LaMatrice(level.old.λ, rows: width, cols: 1, deallocator: nil) }
	
	private var Δχ: LaObjet { return LaMatrice(delta.new.χ, rows: width, cols: 1, deallocator: nil) }
	private var Δσ: LaObjet { return LaMatrice(delta.new.σ, rows: width, cols: 1, deallocator: nil) }
	private var Δμ: LaObjet { return LaMatrice(delta.new.μ, rows: width, cols: 1, deallocator: nil) }
	
	private var _Δχ: LaObjet { return LaMatrice(delta.old.χ, rows: width, cols: 1, deallocator: nil) }
	private var _Δμ: LaObjet { return LaMatrice(delta.old.μ, rows: width, cols: 1, deallocator: nil) }
	private var _Δσ: LaObjet { return LaMatrice(delta.old.σ, rows: width, cols: 1, deallocator: nil) }
	
}
extension Cell {
	public var active: [Bool] {
		set {
			if 0 < width {
				NSData(bytesNoCopy: UnsafeMutablePointer(newValue.map({Float($0)})), length: sizeof(Float)*newValue.count, freeWhenDone: false).getBytes(UnsafeMutablePointer<Void>(state.new.κ), length: sizeof(Float)*state.new.κ.count)
				ready.insert(.κ)
			}
		}
		get {
			return 0 < width ? collect().array.map { Bool($0) } : []
		}
	}
	public var answer: [Bool] {
		set {
			if 0 < width {
				NSData(bytesNoCopy: UnsafeMutablePointer(newValue.map({Float($0)})), length: sizeof(Float)*state.new.ψ.count, freeWhenDone: false).getBytes(UnsafeMutablePointer<Void>(state.new.ψ), length: sizeof(Float)*state.new.ψ.count)
				ready.insert(.ψ)
			}
		}
		get {
			return 0 < width ? state.new.ψ.map { Bool($0) } : []
		}
	}
	public var isRecurrent: Bool {
		return circular != nil || decay != nil
	}
}
extension Context {
	public func newCell (type: DistributionType, width: Int, label: String = "", recur: Bool = false, buffer: Bool = false, input: [Cell] = [] ) throws -> Cell {
		guard let cell: Cell = new() else {
			throw Error.CoreData.InsertionFails(entity: Cell.self)
		}
		cell.label = label
		cell.width = width
		cell.type = type
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
			attribute [ "width" ] = width
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
	/*
	public func unchainCell(let output output: Cell, let input: Cell) {
		output.input.filter{ $0.input === input }.forEach {
			deleteObject($0)
		}
	}
	*/
}