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
		grad: Array<Float>()
	)
	private var μoptimizer: GradientOptimizer = SGD()
	private var σoptimizer: GradientOptimizer = SGD()
}
internal extension Arcane {
	@NSManaged private var location: NSData
	@NSManaged private var logscale: NSData
	@NSManaged private var rows: Int
	@NSManaged private var cols: Int
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
		
		cache.grad = Array<Float>(count: count, repeatedValue: 0)
		
		location.getBytes(cache.logμ, length: sizeof(Float)*count)
		logscale.getBytes(cache.logσ, length: sizeof(Float)*count)
		
		setPrimitiveValue(NSData(bytesNoCopy: cache.logμ, length: sizeof(Float)*count, freeWhenDone: false), forKey: Arcane.locationKey)
		setPrimitiveValue(NSData(bytesNoCopy: cache.logσ, length: sizeof(Float)*count, freeWhenDone: false), forKey: Arcane.logscaleKey)
		
		refresh()
		
		μoptimizer = (managedObjectContext as? Context)?.optimizerFactory(count) ?? μoptimizer
		σoptimizer = (managedObjectContext as? Context)?.optimizerFactory(count) ?? σoptimizer
	}
	private func refresh() {
		let count: Int = rows * cols
		cblas_scopy(Int32(count), cache.logμ, 1, cache.μ, 1)
		vvexpf(cache.σ, cache.logσ, [Int32(count)])
		( 1.0 + σ ).getBytes(cache.σ)
		vvlogf(cache.σ, cache.σ, [Int32(count)])
	}
	internal func update(distribution: Distribution.Type, Δμ: LaObjet, Δσ: LaObjet) {
		
		assert(Δμ.rows == rows)
		assert(Δμ.cols == cols)
		assert(Δσ.rows == rows)
		assert(Δσ.cols == cols)
		
		let count: Int = rows * cols

		willChangeValueForKey(Arcane.locationKey)
		( logμ + μoptimizer.optimize(Δx: distribution.Δμ(Δ: Δμ, μ: μ), x: logμ) ).getBytes(cache.logμ)
		didChangeValueForKey(Arcane.locationKey)
		
		vDSP_vneg(cache.σ, 1, &cache.grad, 1, vDSP_Length(count))
		vvexpf(&cache.grad, cache.grad, [Int32(count)])
		
		willChangeValueForKey(Arcane.logscaleKey)
		( logσ + ( 1 - grad ) * σoptimizer.optimize(Δx: distribution.Δσ(Δ: Δσ, σ: σ), x: logσ) ).getBytes(cache.logσ)
		didChangeValueForKey(Arcane.logscaleKey)
		
		refresh()
	}
	internal func adjust(μ μ: Float, σ: Float) {
		
		let count: Int = rows * cols
		
		vDSP_vfill([μ], cache.μ, 1, vDSP_Length(count))
		
		willChangeValueForKey(Arcane.locationKey)
		cblas_scopy(Int32(count), cache.μ, 1, cache.logμ, 1)
		didChangeValueForKey(Arcane.locationKey)

		vDSP_vfill([σ], cache.σ, 1, vDSP_Length(count))
		
		willChangeValueForKey(Arcane.logscaleKey)
		vvexpf(cache.logσ, cache.σ, [Int32(count)])
		(logσ - 1).getBytes(cache.logσ)
		vvlogf(cache.logσ, cache.logσ, [Int32(count)])
		didChangeValueForKey(Arcane.logscaleKey)

		
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
	private var grad: LaObjet {
		return LaMatrice(cache.grad, rows: rows, cols: cols, deallocator: nil)
	}
	private var logμ: LaObjet {
		return LaMatrice(cache.logμ, rows: rows, cols: cols, deallocator: nil)
	}
	private var logσ: LaObjet {
		return LaMatrice(cache.logσ, rows: rows, cols: cols, deallocator: nil)
	}
	internal func shuffle(distribution: Distribution.Type) {
		let count: Int = rows * cols
		assert(cache.χ.count==count)
		assert(cache.ψ.count==count)
		arc4random_buf(&cache.ψ, sizeof(UInt32)*count)
		distribution.rng(cache.χ, ψ: cache.ψ, μ: μ, σ: σ)
	}
}