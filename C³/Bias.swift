//
//  Bias.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Metal
import CoreData
internal class Bias: Cauchy {
	private struct grad {
		let μ: MTLBuffer
		let σ: MTLBuffer
	}
	private var grads: RingBuffer<grad> = RingBuffer<grad>(array: [])
}

extension Bias {
	@NSManaged internal var output: Cell
	
}

extension Bias {
	internal override func setup(let context: Context) {
		super.setup(context)
		if output.isRecurrent {
			let width: Int = output.width
			let length: Int = 2
			grads = RingBuffer<grad>(array: (0..<length).map{(_)in
				grad(
					μ: context.newBuffer(length: sizeof(Float)*width*width, options: .StorageModePrivate),
					σ: context.newBuffer(length: sizeof(Float)*width*width, options: .StorageModePrivate)
				)
			})
		}
	}
	internal func collect(let level level: (MTLBuffer, MTLBuffer, MTLBuffer)) {
		if let context: Context = managedObjectContext as? Context {
			let width: Int = output.width
			self.dynamicType.collect(context: context, level: level, bias: (χ, μ, σ), width: width)
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
	}
	internal func correct(let η η: Float, let Δ: (MTLBuffer, MTLBuffer)) {
		if let context: Context = managedObjectContext as? Context {
			let width: Int = output.width
			func schedule() {
				willChangeValueForKey(self.dynamicType.logμkey)
				willChangeValueForKey(self.dynamicType.logσkey)
			}
			func complete() {
				didChangeValueForKey(self.dynamicType.logσkey)
				didChangeValueForKey(self.dynamicType.logμkey)
			}
			if 0 < grads.length {
				grads.progress()
				self.dynamicType.gradientEye(context: context, grad: (grads.new.μ, grads.new.σ), width: output.width)
				self.dynamicType.correct(context: context, η: η, bias: (logμ, logσ, μ, σ), grad: (grads.new.μ, grads.new.σ), Δ: Δ, width: width, schedule: schedule, complete: complete)
			} else {
				self.dynamicType.correctLightWeight(context: context, η: η, bias: (logμ, logσ, μ, σ), Δ: Δ, width: width, schedule: schedule, complete: complete)
			}
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
	}
}
extension Bias {
	internal class var collectKernel: String { return "biasCollect" }
	internal class var correctKernel: String { return "biasCorrect" }
	internal class var correctLightWeightKernel: String { return "biasCorrectLightWeight" }
	internal class var gradientEyeKerel: String { return "biasGradientEye" }
	internal static func collect(let context context: Context, let level: (MTLBuffer, MTLBuffer, MTLBuffer), let bias: (MTLBuffer, MTLBuffer, MTLBuffer), let width: Int) {
		context.newComputeCommand(function: collectKernel) {
			$0.setBuffer(level.0, offset: 0, atIndex: 0)
			$0.setBuffer(level.1, offset: 0, atIndex: 1)
			$0.setBuffer(level.2, offset: 0, atIndex: 2)
			$0.setBuffer(bias.0, offset: 0, atIndex: 3)
			$0.setBuffer(bias.1, offset: 0, atIndex: 4)
			$0.setBuffer(bias.2, offset: 0, atIndex: 5)
			$0.dispatchThreadgroups(MTLSize(width: width/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func correct(let context context: Context, let η: Float, let bias: (MTLBuffer, MTLBuffer, MTLBuffer, MTLBuffer), let grad: (MTLBuffer, MTLBuffer), let Δ: (MTLBuffer, MTLBuffer), let width: Int, let bs: Int = 64, let schedule: (()->())? = nil, let complete: (()->())? = nil) {
		context.newComputeCommand(function: correctKernel, schedule: schedule, complete: complete) {
			$0.setBuffer(bias.0, offset: 0, atIndex: 0)
			$0.setBuffer(bias.1, offset: 0, atIndex: 1)
			$0.setBuffer(bias.2, offset: 0, atIndex: 2)
			$0.setBuffer(bias.3, offset: 0, atIndex: 3)
			$0.setBuffer(grad.0, offset: 0, atIndex: 4)
			$0.setBuffer(grad.1, offset: 0, atIndex: 5)
			$0.setBuffer(Δ.0, offset: 0, atIndex: 6)
			$0.setBuffer(Δ.1, offset: 0, atIndex: 7)
			$0.setBytes([uint(width/4), uint(width/4)], length: sizeof(uint)*2, atIndex: 8)
			$0.setBytes([η], length: sizeof(Float), atIndex: 9)
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*bs, atIndex: 0)
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*bs, atIndex: 1)
			$0.dispatchThreadgroups(MTLSize(width: width/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: bs, height: 1, depth: 1))
		}
	}
	internal static func correctLightWeight(let context context: Context, let η: Float, let bias: (MTLBuffer, MTLBuffer, MTLBuffer, MTLBuffer), let Δ: (MTLBuffer, MTLBuffer), let width: Int, let schedule: (()->())? = nil, let complete: (()->())? = nil) {
		context.newComputeCommand(function: correctLightWeightKernel, schedule: schedule, complete: complete) {
			$0.setBuffer(bias.0, offset: 0, atIndex: 0)
			$0.setBuffer(bias.1, offset: 0, atIndex: 1)
			$0.setBuffer(bias.2, offset: 0, atIndex: 2)
			$0.setBuffer(bias.3, offset: 0, atIndex: 3)
			$0.setBuffer(Δ.0, offset: 0, atIndex: 4)
			$0.setBuffer(Δ.1, offset: 0, atIndex: 5)
			$0.setBytes([η], length: sizeof(Float), atIndex: 6)
			$0.dispatchThreadgroups(MTLSize(width: width/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func gradientEye(let context context: Context, let grad: (MTLBuffer, MTLBuffer), let width: Int) {
		assert(grad.0.length==grad.1.length)
		context.newBlitCommand {
			$0.fillBuffer(grad.0, range: NSRange(location: 0, length: grad.0.length), value: 0)
			$0.fillBuffer(grad.1, range: NSRange(location: 0, length: grad.1.length), value: 0)
		}
		context.newComputeCommand(function: gradientEyeKerel) {
			$0.setBuffer(grad.0, offset: 0, atIndex: 0)
			$0.setBuffer(grad.1, offset: 0, atIndex: 1)
			$0.dispatchThreadgroups(MTLSize(width: width/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
}
extension Bias {
	private func bind(let output o: Cell) {
		output = o
		resize(count: output.width)
	}
}
extension Context {
	internal func newBias(let output output: Cell) throws -> Bias {
		guard let bias: Bias = new() else {
			throw Error.CoreData.InsertionFails(entity: Bias.className())
		}
		bias.bind(output: output)
		return bias
	}
}