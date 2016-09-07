//
//  Arcane.swift
//  Mac
//
//  Created by Kota Nakano on 8/29/16.
//
//
import Accelerate
import CoreData

internal class Arcane: NSManagedObject {
	private let group: dispatch_group_t = dispatch_group_create()
	private var cache = (
		ψ: Array<UInt32>(),
		χ: Array<Float>(),
		b: Array<Float>(),
		μ: UnsafeMutablePointer<Float>(nil),
		σ: UnsafeMutablePointer<Float>(nil),
		logb: Array<Float>(),
		logμ: UnsafeMutablePointer<Float>(nil),
		logσ: UnsafeMutablePointer<Float>(nil),
		gradb: Array<Float>(),
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
		
		let count: Int = rows * cols
		
		cache.χ = Array<Float>(count: count, repeatedValue: 0)
		cache.ψ = Array<UInt32>(count: count, repeatedValue: 0)
		
		cache.b = Array<Float>(count: 2*count, repeatedValue: 0)//ARC
		cache.μ = UnsafeMutablePointer<Float>(cache.b).advancedBy(0*count)
		cache.σ = UnsafeMutablePointer<Float>(cache.b).advancedBy(1*count)
		
		cache.logb = Array<Float>(count: 2*count, repeatedValue: 0)//ARC
		cache.logμ = UnsafeMutablePointer<Float>(cache.logb).advancedBy(0*count)
		cache.logσ = UnsafeMutablePointer<Float>(cache.logb).advancedBy(1*count)
		
		cache.gradb = Array<Float>(count: 2*count, repeatedValue: 0)//ARC
		cache.gradμ = UnsafeMutablePointer<Float>(cache.gradb).advancedBy(0*count)
		cache.gradσ = UnsafeMutablePointer<Float>(cache.gradb).advancedBy(1*count)
		
		location.getBytes(cache.logμ, length: sizeof(Float)*count)
		logscale.getBytes(cache.logσ, length: sizeof(Float)*count)
		
		setPrimitiveValue(NSData(bytesNoCopy: cache.logμ, length: sizeof(Float)*count, freeWhenDone: false), forKey: Arcane.locationKey)
		setPrimitiveValue(NSData(bytesNoCopy: cache.logσ, length: sizeof(Float)*count, freeWhenDone: false), forKey: Arcane.logscaleKey)
		
		arc4random_buf(&cache.ψ, sizeof(UInt32)*count)
		refresh()
		
		optimizer = (managedObjectContext as? Context)?.optimizerFactory(2*count) ?? optimizer
		μoptimizer = (managedObjectContext as? Context)?.optimizerFactory(count) ?? μoptimizer
		σoptimizer = (managedObjectContext as? Context)?.optimizerFactory(count) ?? σoptimizer
	}
	private func refresh() {
		let count: Int = rows * cols
		self.dynamicType.μ(cache.μ, logμ: cache.logμ, count: count)
		self.dynamicType.σ(cache.σ, logσ: cache.logσ, count: count)
	}
	internal func update(distribution: Distribution.Type, Δμ: LaObjet, Δσ: LaObjet) {
		
		assert(Δμ.rows == rows)
		assert(Δμ.cols == cols)
		assert(Δσ.rows == rows)
		assert(Δσ.cols == cols)
	
		let count: Int = rows * cols
	
		func update() {
		
		self.dynamicType.gradμ(cache.gradμ, μ: cache.μ, count: count)
		self.dynamicType.gradσ(cache.gradσ, σ: cache.σ, count: count)
			
		distribution.Δμ(Δ: gradμ * Δμ, μ: μ).getBytes(cache.gradμ)
		distribution.Δσ(Δ: gradσ * Δσ, σ: σ).getBytes(cache.gradσ)
		
		optimizer.optimize(
			Δx: LaMatrice(cache.gradb, rows: 2*count, cols: 1, deallocator: nil),
			x: LaMatrice(cache.logb, rows: 2*count, cols: 1, deallocator: nil)
		).getBytes(cache.gradb)
			
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
		var neg: Float = -1
		var pos: Float = 1
		vDSP_vneg(σ, 1, gradσ, 1, vDSP_Length(count))
		vvexpf(gradσ, gradσ, &len)
		vDSP_vsmsa(gradσ, 1, &neg, &pos, gradσ, 1, vDSP_Length(count))
	}
}
extension Arcane {
	private static let queue: dispatch_queue_t = dispatch_queue_create("com.organi2e.kotan.kn.C3.Arcane", DISPATCH_QUEUE_CONCURRENT)
	internal func sync() {
		dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
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
		assert(cache.χ.count==count)
		assert(cache.ψ.count==count)
		func shuffle() {
			arc4random_buf(noise, count*sizeof(UInt32))
			distribution.rng(UnsafeMutablePointer<Float>(cache.χ), ψ: cache.ψ, μ: cache.μ, σ: cache.σ, count: count)
		}
		shuffle()
		//sync()
		//dispatch_group_async(group, self.dynamicType.queue, shuffle)
	}
}