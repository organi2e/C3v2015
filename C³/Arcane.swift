//
//  Arcane.swift
//  Mac
//
//  Created by Kota Nakano on 8/29/16.
//
//
import Accelerate
import CoreData

internal protocol RandomVariable {
	var χ: LaObjet { get }
	var μ: LaObjet { get }
	var σ: LaObjet { get }
}

internal class Arcane: NSManagedObject {
	private let group: dispatch_group_t = dispatch_group_create()
	private var seed: [UInt32] = []
	private var value: [Float] = []
	private var mu: [Float] = []
	private var sigma: [Float] = []
	private var logsigma: [Float] = []
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
		
		seed = [UInt32](count: count, repeatedValue: 0)
		value = [Float](count: count, repeatedValue: 0)
		mu = [Float](count: count, repeatedValue: 0)
		sigma = [Float](count: count, repeatedValue: 0)
		logsigma = [Float](count: count, repeatedValue: 0)
		
		location.getBytes(UnsafeMutablePointer<Void>(mu), length: sizeof(Float)*count)
		logscale.getBytes(UnsafeMutablePointer<Void>(logsigma), length: sizeof(Float)*count)
		
		setPrimitiveValue(NSData(bytesNoCopy: UnsafeMutablePointer<Void>(mu), length: sizeof(Float)*count, freeWhenDone: false), forKey: self.dynamicType.locationKey)
		setPrimitiveValue(NSData(bytesNoCopy: UnsafeMutablePointer<Void>(logsigma), length: sizeof(Float)*count, freeWhenDone: false), forKey: self.dynamicType.logscaleKey)
	
		update(0, Δμ: nil, Δσ: nil)
	}
	internal func update(η: Float, Δμ: LaObjet? = nil, Δσ: LaObjet? = nil) {
		if let Δμ: LaObjet = Δμ where Δμ.rows == rows && Δμ.cols == cols {
			willChangeValueForKey(self.dynamicType.locationKey)
			(μ + η * Δμ).getBytes(mu)
			didChangeValueForKey(self.dynamicType.locationKey)
		}
		if let Δσ: LaObjet = Δσ where Δσ.rows == rows && Δσ.cols == cols {
			let logσ: LaObjet = matrix(logsigma, rows: rows, cols: cols, deallocator: nil)
			
			vDSP_vneg(sigma, 1, UnsafeMutablePointer<Float>(sigma), 1, vDSP_Length(sigma.count))
			vvexpf(UnsafeMutablePointer<Float>(sigma), sigma, [Int32(sigma.count)])
			
			willChangeValueForKey(self.dynamicType.logscaleKey)
			(logσ+(1-σ)*η*Δσ).getBytes(logsigma)
			didChangeValueForKey(self.dynamicType.logscaleKey)
		}
		vvexp2f(UnsafeMutablePointer<Float>(sigma), logsigma, [Int32(logsigma.count)])
		(1.0+σ).getBytes(sigma)
		vvlog2f(UnsafeMutablePointer<Float>(sigma), sigma, [Int32(sigma.count)])
	}
	internal func resize(rows r: Int, cols c: Int) {
		rows = r
		cols = c
		location = NSData(bytes: [Float](count: rows*cols, repeatedValue: 0), length: sizeof(Float)*rows*cols)
		logscale = NSData(bytes: [Float](count: rows*cols, repeatedValue: 0), length: sizeof(Float)*rows*cols)
		setup()
	}
}
extension Arcane: RandomVariable {
	internal var χ: LaObjet {
		return matrix(value, rows: rows, cols: cols, deallocator: nil)
	}
	internal var μ: LaObjet {
		return matrix(mu, rows: rows, cols: cols, deallocator: nil)
	}
	internal var σ: LaObjet {
		return matrix(sigma, rows: rows, cols: cols, deallocator: nil)
	}
}
extension Arcane: RandomNumberGeneratable {
	internal func shuffle(distribution: StableDistribution.Type) {
		let count: Int = rows * cols
		assert(value.count==count)
		assert(mu.count==count)
		assert(sigma.count==count)
		assert(seed.count==count)
		arc4random_buf(UnsafeMutablePointer<Void>(seed), sizeof(UInt32)*count)
		distribution.rng(value, μ: mu, σ: sigma, ψ: seed)
	}
}