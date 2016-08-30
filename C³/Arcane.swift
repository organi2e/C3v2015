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
		χ: Array<Float>(),
		μ: Array<Float>(),
		σ: Array<Float>(),
		ψ: Array<UInt32>(),
		logμ: Array<Float>(),
		logσ: Array<Float>()
	)
}
internal extension Arcane {
	@NSManaged private var location: NSData
	@NSManaged private var logscale: NSData
	@NSManaged private var rows: Int
	@NSManaged private var cols: Int
}
internal extension Arcane {
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
		cache.μ = Array<Float>(count: count, repeatedValue: 0)
		cache.σ = Array<Float>(count: count, repeatedValue: 0)
		cache.ψ = Array<UInt32>(count: count, repeatedValue: 0)
		cache.logμ = Array<Float>(count: count, repeatedValue: 0)
		cache.logσ = Array<Float>(count: count, repeatedValue: 0)
		
		location.getBytes(&cache.logμ, length: sizeof(Float)*count)
		logscale.getBytes(&cache.logσ, length: sizeof(Float)*count)
		
		setPrimitiveValue(NSData(bytesNoCopy: &cache.logμ, length: sizeof(Float)*count, freeWhenDone: false), forKey: Arcane.locationKey)
		setPrimitiveValue(NSData(bytesNoCopy: &cache.logσ, length: sizeof(Float)*count, freeWhenDone: false), forKey: Arcane.logscaleKey)
	
		update(0, Δμ: nil, Δσ: nil)
	}
	internal func update(η: Float, Δμ: LaObjet? = nil, Δσ: LaObjet? = nil) {
		if let Δμ: LaObjet = Δμ where Δμ.rows == rows && Δμ.cols == cols {
			willChangeValueForKey(Arcane.locationKey)
			( logμ + η * Δμ ).getBytes(cache.logμ)
			didChangeValueForKey(Arcane.locationKey)
		}
		cblas_scopy(Int32(rows*cols), cache.logμ, 1, &cache.μ, 1)
		if let Δσ: LaObjet = Δσ where Δσ.rows == rows && Δσ.cols == cols {
			vDSP_vneg(cache.σ, 1, &cache.σ, 1, vDSP_Length(cache.σ.count))
			vvexpf(&cache.σ, cache.σ, [Int32(cache.σ.count)])
			willChangeValueForKey(Arcane.logscaleKey)
			( logσ + η * ( 1 - σ ) * Δσ ).getBytes(cache.logσ)
			didChangeValueForKey(Arcane.logscaleKey)
		}
		vvexp2f(&cache.σ, cache.logσ, [Int32(cache.logσ.count)])
		(1.0+σ).getBytes(cache.σ)
		vvlog2f(&cache.σ, cache.σ, [Int32(cache.σ.count)])
	}
	internal func resize(rows r: Int, cols c: Int) {
		rows = r
		cols = c
		do {
			let count: Int = rows * cols
			location = NSData(bytes: [Float](count: count, repeatedValue: 0), length: sizeof(Float)*count)
			logscale = NSData(bytes: [Float](count: count, repeatedValue: 0), length: sizeof(Float)*count)
		}
		setup()
	}
}
extension Arcane: RandomNumberGeneratable {
	internal var χ: LaObjet {
		return matrix(cache.χ, rows: rows, cols: cols, deallocator: nil)
	}
	internal var μ: LaObjet {
		return matrix(cache.μ, rows: rows, cols: cols, deallocator: nil)
	}
	internal var σ: LaObjet {
		return matrix(cache.σ, rows: rows, cols: cols, deallocator: nil)
	}
	private var logμ: LaObjet {
		return matrix(cache.logμ, rows: rows, cols: cols, deallocator: nil)
	}
	private var logσ: LaObjet {
		return matrix(cache.logσ, rows: rows, cols: cols, deallocator: nil)
	}
	internal func shuffle(distribution: StableDistribution.Type) {
		let count: Int = rows * cols
		assert(cache.χ.count==count)
		assert(cache.μ.count==count)
		assert(cache.σ.count==count)
		assert(cache.ψ.count==count)
		arc4random_buf(&cache.ψ, sizeof(UInt32)*count)
		distribution.rng(cache.χ, μ: cache.μ, σ: cache.σ, ψ: cache.ψ)
	}
}