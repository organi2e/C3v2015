//
//  Arcane.swift
//  Mac
//
//  Created by Kota Nakano on 8/29/16.
//
//
import Accelerate
import CoreData
import Metal
internal class Arcane: NSManagedObject {

	internal struct Buffer {
		private let data: MTLBuffer
		private let sync: dispatch_group_t = dispatch_group_create()
		func enter() {
			dispatch_group_enter(sync)
		}
		func leave() {
			dispatch_group_leave(sync)
		}
		func merge() {
			dispatch_group_wait(sync, DISPATCH_TIME_FOREVER)
		}
		var bytes: UnsafeMutablePointer<Float> {
			return UnsafeMutablePointer<Float>(data.contents())
		}
	}
	
	private var value: Buffer! = nil
	private var param: Buffer! = nil
	private var cover: Buffer! = nil
	private var deriv: Buffer! = nil
	
	private var cache = (
		ψ: Array<UInt32>(),
		χ: UnsafeMutablePointer<Float>(nil),
		μ: UnsafeMutablePointer<Float>(nil),
		σ: UnsafeMutablePointer<Float>(nil),
		logμ: UnsafeMutablePointer<Float>(nil),
		logσ: UnsafeMutablePointer<Float>(nil),
		gradμ: UnsafeMutablePointer<Float>(nil),
		gradσ: UnsafeMutablePointer<Float>(nil)
	)
	
	private var optimizer: GradientOptimizer = SGD()
	private var μoptimizer: GradientOptimizer = SGD()
	private var σoptimizer: GradientOptimizer = SGD()
}
internal extension Arcane {
	@NSManaged private var location: NSData
	@NSManaged private var logscale: NSData
	@NSManaged internal var rows: Int
	@NSManaged internal var cols: Int
}
internal extension Arcane {
	override func awakeFromInsert() {
		super.awakeFromInsert()
		resize(rows: 1, cols: 1)
	}
	internal override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
	internal override func awakeFromSnapshotEvents(flags: NSSnapshotEventType) {
		super.awakeFromSnapshotEvents(flags)
		setup()
	}
}
internal extension Arcane {
	private static let locationKey: String = "location"
	private static let logscaleKey: String = "logscale"
	internal func setup() {
		
		guard let context: Context = managedObjectContext as? Context else {
			fatalError(Context.Error.InvalidContext.rawValue)
		}
		
		let count: Int = rows * cols
		
		value = Buffer(data: context.newBuffer(length: sizeof(Float)*2*count, options: .StorageModeShared))
		param = Buffer(data: context.newBuffer(length: sizeof(Float)*2*count, options: .StorageModeShared))
		cover = Buffer(data: context.newBuffer(length: sizeof(Float)*2*count, options: .StorageModeShared))
		deriv = Buffer(data: context.newBuffer(length: sizeof(Float)*2*count, options: .StorageModeShared))
		
		cache.χ = value.bytes
		cache.ψ = Array<UInt32>(count: count, repeatedValue: 0)
		
		cache.μ = param.bytes
		cache.σ = cache.μ.advancedBy(count)
		
		cache.logμ = cover.bytes
		cache.logσ = cache.logμ.advancedBy(count)
		
		cache.gradμ = deriv.bytes
		cache.gradσ = cache.gradμ.advancedBy(count)
		
		location.getBytes(cache.logμ, length: sizeof(Float)*count)
		logscale.getBytes(cache.logσ, length: sizeof(Float)*count)
		
		setPrimitiveValue(NSData(bytesNoCopy: cache.logμ, length: sizeof(Float)*count, freeWhenDone: false), forKey: self.dynamicType.locationKey)
		setPrimitiveValue(NSData(bytesNoCopy: cache.logσ, length: sizeof(Float)*count, freeWhenDone: false), forKey: self.dynamicType.logscaleKey)
		
		refresh()
		
		optimizer = (managedObjectContext as? Context)?.optimizerFactory(2*count) ?? optimizer
		μoptimizer = (managedObjectContext as? Context)?.optimizerFactory(count) ?? μoptimizer
		σoptimizer = (managedObjectContext as? Context)?.optimizerFactory(count) ?? σoptimizer
	}
	private func refresh() {
		guard let context: Context = managedObjectContext as? Context else {
			fatalError(Context.Error.InvalidContext.rawValue)
		}
		let count: Int = rows * cols
		self.dynamicType.param(context, param: param, cover: cover, count: count)
		self.dynamicType.deriv(context, deriv: deriv, param: param, count: count)
	}
	internal func update(distribution: Distribution.Type, Δμ: LaObjet, Δσ: LaObjet) {
	
		let count: Int = rows * cols
		
		assert(Δμ.count == count)
		assert(Δσ.count == count)
		
		func update() {
		
			deriv.merge()
			
			distribution.Δμ(
				Δ: LaMatrice(cache.gradμ, rows: Δμ.rows, cols: Δμ.cols, deallocator: nil) * Δμ,
				μ: LaMatrice(cache.μ, rows: Δμ.rows, cols: Δμ.cols, deallocator: nil))
			.getBytes(cache.gradμ)
			
			distribution.Δσ(
				Δ: LaMatrice(cache.gradσ, rows: Δσ.rows, cols: Δσ.cols, deallocator: nil) * Δσ,
				σ: LaMatrice(cache.σ, rows: Δσ.rows, cols: Δσ.cols, deallocator: nil))
			.getBytes(cache.gradσ)
		
			optimizer.optimize(
				Δx: LaMatrice(deriv.bytes, rows: count, cols: 1, deallocator: nil),
				x: LaMatrice(cover.bytes, rows: count, cols: 1, deallocator: nil)
			).getBytes(deriv.bytes)
			
			willChangeValueForKey(self.dynamicType.locationKey)
			( logμ - gradμ ).getBytes(cache.logμ)
			didChangeValueForKey(self.dynamicType.locationKey)
		
			willChangeValueForKey(self.dynamicType.logscaleKey)
			( logσ - gradσ ).getBytes(cache.logσ)
			didChangeValueForKey(self.dynamicType.logscaleKey)
			
			refresh()
		}
		//sync()
		//dispatch_group_async(group, self.dynamicType.queue, update)
		update()
	}
	internal func adjust(μ μ: Float, σ: Float) {
		
		let count: Int = rows * cols
		
		vDSP_vfill([μ], cache.μ, 1, vDSP_Length(count))
		willChangeValueForKey(self.dynamicType.locationKey)
		self.dynamicType.logμ(cache.logμ, μ: cache.μ, count: count)
		didChangeValueForKey(self.dynamicType.locationKey)

		vDSP_vfill([σ], cache.σ, 1, vDSP_Length(count))
		willChangeValueForKey(self.dynamicType.logscaleKey)
		self.dynamicType.logσ(cache.logσ, σ: cache.σ, count: count)
		didChangeValueForKey(self.dynamicType.logscaleKey)

	}
	internal func resize(rows r: Int, cols c: Int) {
		
		rows = r
		cols = c

		let count: Int = rows * cols
		location = NSData(bytes: [Float](count: count, repeatedValue: 0), length: sizeof(Float)*count)
		logscale = NSData(bytes: [Float](count: count, repeatedValue: 0), length: sizeof(Float)*count)
		
		setup()
	}
}
extension Arcane {
	internal static func μ(μ: UnsafeMutablePointer<Float>, logμ: UnsafePointer<Float>, count: Int) {
		cblas_scopy(Int32(count), logμ, 1, μ, 1)
	}
	internal static func logμ(logμ: UnsafeMutablePointer<Float>, μ: UnsafePointer<Float>, count: Int) {
		cblas_scopy(Int32(count), μ, 1, logμ, 1)
	}
	internal static func gradμ(gradμ: UnsafeMutablePointer<Float>, μ: UnsafePointer<Float>, count: Int) {
		var one: Float = 1
		vDSP_vfill(&one, gradμ, 1, vDSP_Length(count))
	}
	internal static func σ(σ: UnsafeMutablePointer<Float>, logσ: UnsafePointer<Float>, count: Int) {
		var len: Int32 = Int32(count)
		var one: Float = 1
		vvexpf(σ, logσ, &len)
		vDSP_vsadd(σ, 1, &one, σ, 1, vDSP_Length(count))
		vvlogf(σ, σ, &len)
	}
	internal static func logσ(logσ: UnsafeMutablePointer<Float>, σ: UnsafePointer<Float>, count: Int) {
		var len: Int32 = Int32(count)
		var neg: Float = -1
		vvexpf(logσ, σ, &len)
		vDSP_vsadd(logσ, 1, &neg, logσ, 1, vDSP_Length(count))
		vvlogf(logσ, logσ, &len)
	}
	internal static func gradσ(gradσ: UnsafeMutablePointer<Float>, σ: UnsafePointer<Float>, count: Int) {
		var len: Int32 = Int32(count)
		var one: Float = 1
		vDSP_vneg(σ, 1, gradσ, 1, vDSP_Length(count))
		vvexpf(gradσ, gradσ, &len)
		vDSP_vneg(gradσ, 1, gradσ, 1, vDSP_Length(count))
		vDSP_vsadd(gradσ, 1, &one, gradσ, 1, vDSP_Length(count))
	}
}
extension Arcane: RandomNumberGeneratable {
	internal var χ: LaObjet {
		return LaMatrice(cache.χ, rows: rows, cols: cols, deallocator: nil)
	}
	internal var μ: LaObjet {
		return LaMatrice(cache.μ, rows: rows, cols: cols, deallocator: nil)
	}
	internal var σ: LaObjet {
		return LaMatrice(cache.σ, rows: rows, cols: cols, deallocator: nil)
	}
	private var gradμ: LaObjet {
		return LaMatrice(cache.gradμ, rows: rows, cols: cols, deallocator: nil)
	}
	private var gradσ: LaObjet {
		return LaMatrice(cache.gradσ, rows: rows, cols: cols, deallocator: nil)
	}
	private var logμ: LaObjet {
		return LaMatrice(cache.logμ, rows: rows, cols: cols, deallocator: nil)
	}
	private var logσ: LaObjet {
		return LaMatrice(cache.logσ, rows: rows, cols: cols, deallocator: nil)
	}
	internal func shuffle(distribution: Distribution.Type) {
		let noise: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(cache.ψ)
		let count: Int = rows * cols
		assert(cache.ψ.count==count)
		func shuffle() {
			arc4random_buf(noise, count*sizeof(UInt32))
			param.merge()
			distribution.rng(UnsafeMutablePointer<Float>(cache.χ), ψ: cache.ψ, μ: cache.μ, σ: cache.σ, count: count)
		}
		shuffle()
		//sync()
		//dispatch_group_async(group, self.dynamicType.queue, shuffle)
	}
}
extension Arcane {
	/*internal static func refresh(context: Context, param: deriv: Buffer, cover: Buffer, count: Int) {
		param.enter()
		context.newComputeCommand(function: "arcaneRefresh", complete: param.leave) {
			$0.setBuffer(param.data, offset: sizeof(Float)*0*count, atIndex: 0)
			$0.setBuffer(param.data, offset: sizeof(Float)*1*count, atIndex: 1)
			$0.setBuffer(cover.data, offset: sizeof(Float)*0*count, atIndex: 2)
			$0.setBuffer(cover.data, offset: sizeof(Float)*1*count, atIndex: 3)
			$0.dispatchThreadgroups(MTLSize(width: (count-1)/4+1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}*/
	internal static func param(context: Context, param: Buffer, cover: Buffer, count: Int) {
		param.enter()
		context.newComputeCommand(function: "arcaneValue", complete: param.leave) {
			$0.setBuffer(param.data, offset: sizeof(Float)*0*count, atIndex: 0)
			$0.setBuffer(param.data, offset: sizeof(Float)*1*count, atIndex: 1)
			$0.setBuffer(cover.data, offset: sizeof(Float)*0*count, atIndex: 2)
			$0.setBuffer(cover.data, offset: sizeof(Float)*1*count, atIndex: 3)
			$0.dispatchThreadgroups(MTLSize(width: count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func conver(context: Context, cover: Buffer, param: Buffer, count: Int) {
		cover.enter()
		context.newComputeCommand(function: "arcaneLogValue", complete: cover.leave) {
			$0.setBuffer(cover.data, offset: sizeof(Float)*0*count, atIndex: 0)
			$0.setBuffer(cover.data, offset: sizeof(Float)*1*count, atIndex: 1)
			$0.setBuffer(param.data, offset: sizeof(Float)*0*count, atIndex: 2)
			$0.setBuffer(param.data, offset: sizeof(Float)*1*count, atIndex: 3)
			$0.dispatchThreadgroups(MTLSize(width: count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func deriv(context: Context, deriv: Buffer, param: Buffer, count: Int) {
		deriv.enter()
		context.newComputeCommand(function: "arcaneGradient", complete: deriv.leave) {
			$0.setBuffer(deriv.data, offset: sizeof(Float)*0*count, atIndex: 0)
			$0.setBuffer(deriv.data, offset: sizeof(Float)*1*count, atIndex: 1)
			$0.setBuffer(param.data, offset: sizeof(Float)*0*count, atIndex: 2)
			$0.setBuffer(param.data, offset: sizeof(Float)*1*count, atIndex: 3)
			$0.dispatchThreadgroups(MTLSize(width: count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
}