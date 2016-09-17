//
//  Edge.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//
import CoreData
internal class Edge: Arcane {
	private let gradχ: [Float] = []
	private let gradμ: [Float] = []
	private let gradσ: [Float] = []
}
extension Edge {
	@NSManaged private var input: Cell
	@NSManaged private var output: Cell
}
extension Edge {
	func collect(ignore: Set<Cell>) -> (χ: LaObjet, μ: LaObjet, σ: LaObjet) {
		let state: LaObjet = input.collect(ignore)
		let distribution: SymmetricStableDistribution = output.distribution
		return(
			χ: matrix_product(χ, state),
			μ: matrix_product(distribution.μrate(μ), distribution.μrate(state)),
			σ: matrix_product(distribution.σrate(σ), distribution.σrate(state))
		)
	}
	func correct(ignore: Set<Cell>) -> LaObjet {
		let (Δμ, Δσ) = output.correct(ignore)
		let distribution: SymmetricStableDistribution = output.distribution
		update(Δμ: Δμ, Δσ: Δσ)
		return matrix_product(self.μ.T, Δμ)
		//return matrix_product(self.σ.T, Δ * gσ)
	}
	func collect_clear(compute: Compute) {
		input.collect_clear()
		refresh(compute, distribution: output.distribution)
	}
	func correct_clear() {
		output.correct_clear()
	}
}
/*
extension Edge {
	internal override func setup(context: Context) {
		super.setup(context)
		if true {
			let rows: Int = output.width
			let cols: Int = input.width
			let length: Int = 2
			grads = RingBuffer<grad>(array: (0..<length).map{(_)in
				grad(
					μ: context.newBuffer(length: sizeof(Float)*rows*rows*cols, options: .StorageModePrivate),
					σ: context.newBuffer(length: sizeof(Float)*rows*rows*cols, options: .StorageModePrivate)
				)
			})
		}
	}
	internal override func refresh() {
		super.refresh()
		if 0 < grads.length {
			grads.progress()
			if let context: Context = managedObjectContext as? Context {
				let μ: MTLBuffer = grads.new.μ
				let σ: MTLBuffer = grads.new.σ
				context.newBlitCommand {
					$0.fillBuffer(μ, range: NSRange(location: 0, length: μ.length), value: 0)
					$0.fillBuffer(σ, range: NSRange(location: 0, length: σ.length), value: 0)
				}
			}
		}
	}
	internal func collect(let Φ level: (MTLBuffer, MTLBuffer, MTLBuffer), let ignore: Set<Cell>) {
		let state: MTLBuffer = input.collect_mtl(ignore)
		if let context: Context = managedObjectContext as? Context {
			let rows: Int = output.width
			let cols: Int = input.width
			self.dynamicType.collect(context: context, level: level, edge: (χ, μ, σ), input: state, rows: rows, cols: cols)
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		}
	}
	internal func correct(let η η: Float, let δ: MTLBuffer, let ϰ: MTLBuffer, let ignore: Set<Cell>) {
		let Δ: (χ: MTLBuffer, μ: MTLBuffer, σ: MTLBuffer) = output.correct(η: η, ignore: ignore)
		if let context: Context = managedObjectContext as? Context {
			let rows: Int = output.width
			let cols: Int = input.width
			self.dynamicType.backpropagation(context: context, error: δ, edge: χ, delta: Δ.χ, rows: rows, cols: cols)
			if 0 < grads.length {
				self.dynamicType.gradientInitialize(context: context, grad: (μ: grads.new.μ, σ: grads.new.σ), input: ϰ, rows: rows, cols: cols)
				self.dynamicType.correct(context: context, η: η, edge: (logμ, logσ, μ, σ), grad: (μ: grads.new.μ, σ: grads.new.σ), delta: (Δ.μ, Δ.σ), rows: rows, cols: cols, schedule: willChange, complete: didChange)
			} else {
				self.dynamicType.correctLightWeight(context: context, η: η, edge: (logμ, logσ, μ, σ), input: ϰ, delta: (Δ.μ, Δ.σ), rows: rows, cols: cols, schedule: willChange, complete: didChange)
			}
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		}
	}
	internal func iClear() {
		shuffle()
		input.iClear()
	}
	internal func oClear() {
		refresh()
		output.oClear()
	}
}
extension Edge {
	internal class var collectKernel: String { return "edgeCollect" }
	internal class var correctKernel: String { return "edgeCorrect" }
	internal class var backpropagationKernel: String { return "edgeBackpropagation" }
	internal class var gradientInitializeKernel: String { return "edgeGradientInitialize" }
	internal class var correctLightWeightKernel: String { return "edgeCorrectLightWeight" }
	internal static func collect(let context context: Context, let level: (χ: MTLBuffer, μ: MTLBuffer, σ: MTLBuffer), let edge: (χ: MTLBuffer, μ: MTLBuffer, σ: MTLBuffer), let input: MTLBuffer, let rows: Int, let cols: Int, let bs: Int = 64) {
		
		assert(level.χ.length==sizeof(Float)*rows)
		assert(level.μ.length==sizeof(Float)*rows)
		assert(level.σ.length==sizeof(Float)*rows)
		assert(edge.χ.length==sizeof(Float)*rows*cols)
		assert(edge.μ.length==sizeof(Float)*rows*cols)
		assert(edge.σ.length==sizeof(Float)*rows*cols)
		assert(input.length==sizeof(Float)*cols)
		
		context.newComputeCommand(function: collectKernel) {
			
			$0.setBuffer(level.χ, offset: 0, atIndex: 0)
			$0.setBuffer(level.μ, offset: 0, atIndex: 1)
			$0.setBuffer(level.σ, offset: 0, atIndex: 2)
			$0.setBuffer(edge.χ, offset: 0, atIndex: 3)
			$0.setBuffer(edge.μ, offset: 0, atIndex: 4)
			$0.setBuffer(edge.σ, offset: 0, atIndex: 5)
			$0.setBuffer(input, offset: 0, atIndex: 6)
			
			$0.setBytes([uint(cols/4), uint(rows/4)], length: sizeof(uint)*2, atIndex: 7)
			
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*bs, atIndex: 0)
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*bs, atIndex: 1)
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*bs, atIndex: 2)
			
			$0.dispatchThreadgroups(MTLSize(width: rows/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: bs, height: 1, depth: 1))
			
		}
	}
	internal static func correct(let context context: Context, let η: Float, let edge: (logμ: MTLBuffer, logσ: MTLBuffer, μ: MTLBuffer, σ: MTLBuffer), let grad: (μ: MTLBuffer, σ: MTLBuffer), let delta: (μ: MTLBuffer, σ: MTLBuffer), let rows: Int, let cols: Int, let bs: Int = 64, let schedule: (()->())?=nil, let complete:(()->())?=nil) {
		context.newComputeCommand(function: correctKernel, schedule: schedule, complete: complete) {
			$0.setBuffer(edge.logμ, offset: 0, atIndex: 0)
			$0.setBuffer(edge.logσ, offset: 0, atIndex: 1)
			$0.setBuffer(edge.μ, offset: 0, atIndex: 2)
			$0.setBuffer(edge.σ, offset: 0, atIndex: 3)
			$0.setBuffer(grad.μ, offset: 0, atIndex: 4)
			$0.setBuffer(grad.σ, offset: 0, atIndex: 5)
			$0.setBuffer(delta.μ, offset: 0, atIndex: 6)
			$0.setBuffer(delta.σ, offset: 0, atIndex: 7)
			$0.setBytes([η], length: sizeof(Float), atIndex: 8)
			$0.setBytes([uint(cols), uint(rows/4)], length: sizeof(uint)*2, atIndex: 9)
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*bs, atIndex: 0)
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*bs, atIndex: 1)
			$0.dispatchThreadgroups(MTLSize(width: cols, height: rows/4, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: bs))
		}
	}
	internal static func correctLightWeight(let context context: Context, let η: Float, let edge: (logμ: MTLBuffer, logσ: MTLBuffer, μ: MTLBuffer, σ: MTLBuffer), let input: MTLBuffer, let delta: (μ: MTLBuffer, σ: MTLBuffer), let rows: Int, let cols: Int, let schedule: (()->())?=nil, let complete:(()->())?=nil) {
		context.newComputeCommand(function: correctLightWeightKernel, schedule: schedule, complete: complete) {
			$0.setBuffer(edge.logμ, offset: 0, atIndex: 0)
			$0.setBuffer(edge.logσ, offset: 0, atIndex: 1)
			$0.setBuffer(edge.μ, offset: 0, atIndex: 2)
			$0.setBuffer(edge.σ, offset: 0, atIndex: 3)
			$0.setBuffer(input, offset: 0, atIndex: 4)
			$0.setBuffer(delta.0, offset: 0, atIndex: 5)
			$0.setBuffer(delta.1, offset: 0, atIndex: 6)
			$0.setBytes([η], length: sizeof(Float), atIndex: 7)
			$0.dispatchThreadgroups(MTLSize(width: cols/4, height: rows/4, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func backpropagation(let context context: Context, let error: MTLBuffer, let edge: MTLBuffer, let delta: MTLBuffer, let rows: Int, let cols: Int, let bs: Int = 64) {
		assert(error.length==sizeof(Float)*cols)
		assert(edge.length==sizeof(Float)*rows*cols)
		assert(delta.length==sizeof(Float)*rows)
		context.newComputeCommand(function: backpropagationKernel) {
			$0.setBuffer(error, offset: 0, atIndex: 0)
			$0.setBuffer(edge, offset: 0, atIndex: 1)
			$0.setBuffer(delta, offset: 0, atIndex: 2)
			$0.setBytes([uint(cols/4), uint(rows/4)], length: sizeof(uint)*2, atIndex: 3)
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*bs, atIndex: 0)
			$0.dispatchThreadgroups(MTLSize(width: cols/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: bs, height: 1, depth: 1))
		}
	}
	internal static func gradientInitialize(let context context: Context, let grad: (μ: MTLBuffer, σ: MTLBuffer), let input: MTLBuffer, let rows: Int, let cols: Int) {
		assert(grad.μ.length==sizeof(Float)*rows*rows*cols)
		assert(grad.σ.length==sizeof(Float)*rows*rows*cols)
		assert(input.length==sizeof(Float)*cols)
		context.newComputeCommand(function: gradientInitializeKernel) {
			$0.setBuffer(grad.μ, offset: 0, atIndex: 0)
			$0.setBuffer(grad.σ, offset: 0, atIndex: 1)
			$0.setBuffer(input, offset: 0, atIndex: 2)
			$0.setBytes([uint(cols), uint(rows)], length: sizeof(uint)*2, atIndex: 3)
			$0.dispatchThreadgroups(MTLSize(width: cols, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
}
*/
extension Context {
	internal func newEdge(let output output: Cell, let input: Cell) throws -> Edge {
		guard let edge: Edge = new() else {
			throw Error.CoreData.InsertionFails(entity: Edge.self)
		}
		edge.output = output
		edge.input = input
		edge.resize(rows: output.width, cols: input.width)
		edge.adjust(μ: 0, σ: 1/Float(input.width))
		return edge
	}
}


