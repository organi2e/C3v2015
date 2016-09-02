//
//  Cell.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import Accelerate
import CoreData

public class Cell: NSManagedObject {
	
	private enum Ready {
		case ψ
		case ϰ
		case δ
	}
	
	private var ready: Set<Ready> = Set<Ready>()
	private var state: RingBuffer<(ψ: [Float], ϰ: [Float], δ: [Float])> = RingBuffer<(ψ: [Float], ϰ: [Float], δ: [Float])>(array: [])
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
	@NSManaged private var feedback: Feedback?
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
	public var distribution: Distribution.Type {
		switch type {
		case .Gauss:
			return GaussianDistribution.self
		case .Cauchy:
			return CauchyDistribution.self
		case .False:
			assertionFailure()
			return FalseDistribution.self
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
	public var withFeedback: Bool {
		return feedback != nil
	}
}

extension Cell {
	internal func setup() {
		let count: Int = 2
		state = RingBuffer<(ψ: [Float], ϰ: [Float], δ: [Float])>(array: (0..<count).map{(_)in
			(
				ψ: [Float](count: width, repeatedValue: 0),
				ϰ: [Float](count: width, repeatedValue: 0),
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
		iRefresh()
		oRefresh()
	}
}
extension Cell {
	internal func iRefresh() {
		state.progress()
		level.progress()
	}
	private func oRefresh() {
		delta.progress()
	}
	public func collect_clear() {
		if ready.contains(.ϰ) {
			ready.remove(.ϰ)
			input.forEach {
				$0.collect_clear(distribution)
			}
			iRefresh()
			bias.shuffle(distribution)
		}
	}
	public func correct_clear() {
		if ready.contains(.δ) {
			ready.remove(.δ)
			output.forEach {
				$0.correct_clear()
			}
			oRefresh()
		}
		ready.remove(.ψ)
	}
	public func collect(ignore: Set<Cell> = []) -> LaObjet {
		if ignore.contains(self) {
			return LaMatrice(state.old.ϰ, rows: width, cols: 1, deallocator: nil)
		} else {
			if !ready.contains(.ϰ) {
				ready.insert(.ϰ)
				let sum: [(χ: LaObjet, μ: LaObjet, σ: LaObjet)] = input.map { $0.collect(ignore) } + [ bias.collect() ]
				distribution.synthesize(χ: level.new.χ, μ: level.new.μ, λ: level.new.λ, refer: sum)
				self.dynamicType.step(state.new.ϰ, level: level.new.χ)
				print("\(label), \(level.new.μ)")
			}
			return LaMatrice(state.new.ϰ, rows: width, cols: 1, deallocator: nil)
		}
	}
	public func correct(ignore: Set<Cell> = []) -> (LaObjet, LaObjet, LaObjet, Distribution.Type) {
		if ignore.contains(self) {
			return (
				LaMatrice(delta.old.χ, rows: width, cols: 1, deallocator: nil),
				LaMatrice(delta.old.μ, rows: width, cols: 1, deallocator: nil),
				LaMatrice(delta.old.σ, rows: width, cols: 1, deallocator: nil),
				distribution
			)
		} else {
			if !ready.contains(.δ) {
				ready.insert(.δ)
				if ready.contains(.ψ) {
					let ψ: LaObjet = LaMatrice(state.new.ψ, rows: width, cols: 1, deallocator: nil)
					let ϰ: LaObjet = LaMatrice(state.new.ϰ, rows: width, cols: 1, deallocator: nil)
					let δ: LaObjet = ψ - ϰ
					δ.getBytes(state.new.δ)
				} else {
					let δ: LaObjet = output.map { $0.correct(ignore, ϰ: state.new.ϰ) } .reduce(LaValuer(0)) { $0.0 + $0.1 }
					δ.getBytes(state.new.δ)
				}
				self.dynamicType.sign(state.new.δ, error: state.new.δ)
				distribution.derivate(Δχ: delta.new.χ, Δμ: delta.new.μ, Δσ: delta.new.σ, Δ: state.new.δ, μ: level.new.μ, λ: level.new.λ)
			}
			return (
				LaMatrice(delta.new.χ, rows: width, cols: 1, deallocator: nil),
				LaMatrice(delta.new.μ, rows: width, cols: 1, deallocator: nil),
				LaMatrice(delta.new.σ, rows: width, cols: 1, deallocator: nil),
				distribution
			)
		}
	}
}
extension Cell {
	public var active: [Bool] {
		set {
			NSData(bytesNoCopy: UnsafeMutablePointer(newValue.map({Float($0)})), length: sizeof(Float)*newValue.count, freeWhenDone: false).getBytes(UnsafeMutablePointer<Void>(state.new.ϰ), length: sizeof(Float)*width)
			ready.insert(.ϰ)
		}
		get {
			return collect().array.map { Bool($0) }
		}
	}
	public var answer: [Bool] {
		set {
			NSData(bytesNoCopy: UnsafeMutablePointer(newValue.map({Float($0)})), length: sizeof(Float)*newValue.count, freeWhenDone: false).getBytes(UnsafeMutablePointer<Void>(state.new.ψ), length: sizeof(Float)*width)
			ready.insert(.ψ)
		}
		get {
			return state.new.ψ.map { Bool($0) }
		}
	}
	public var isRecurrent: Bool {
		return feedback != nil || decay != nil
	}
}
extension Cell {
	internal static func step(state: [Float], level: [Float]) {
		assert(state.count==level.count)
		let length: vDSP_Length = vDSP_Length(min(state.count, level.count))
		vDSP_vneg(level, 1, UnsafeMutablePointer<Float>(state), 1, length)
		vDSP_vthrsc(state, 1, [Float(0.0)], [Float(0.5)], UnsafeMutablePointer<Float>(state), 1, length)
		vDSP_vneg(state, 1, UnsafeMutablePointer<Float>(state), 1, length)
		vDSP_vsadd(state, 1, [Float(0.5)], UnsafeMutablePointer<Float>(state), 1, length)
	}
	internal static func sign(delta: [Float], error: [Float]) {
		assert(delta.count==error.count)
		let length: vDSP_Length = vDSP_Length(min(delta.count, error.count))
		let cache: [Float] = [Float](count: Int(length), repeatedValue: 0)
		vDSP_vthrsc(error, 1, [Float(0.0)], [Float( 0.5)], UnsafeMutablePointer<Float>(delta), 1, length)
		vDSP_vneg(error, 1, UnsafeMutablePointer<Float>(cache), 1, length)
		vDSP_vthrsc(UnsafeMutablePointer<Float>(cache), 1, [Float(0.0)], [Float(-0.5)], UnsafeMutablePointer<Float>(cache), 1, length)
		vDSP_vadd(UnsafeMutablePointer<Float>(cache), 1, UnsafeMutablePointer<Float>(delta), 1, UnsafeMutablePointer<Float>(delta), 1, length)
	}
}
extension Context {
	public func newCell (type: DistributionType, width: Int, label: String = "", recur: Bool = false, buffer: Bool = false, input: [Cell] = [] ) throws -> Cell {
		guard let cell: Cell = new() else {
			throw Error.CoreData.InsertionFails(entity: Cell.className())
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