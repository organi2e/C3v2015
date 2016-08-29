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
	private var logmu: [Float] = []
	private var logsigma: [Float] = []
}
internal extension Arcane {
	@NSManaged private var location: NSData
	@NSManaged private var scale: NSData
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
	internal func setup() {
		let count: Int = rows * cols
		seed = [UInt32](count: count, repeatedValue: 0)
		value = [Float](count: count, repeatedValue: 0)
		mu = [Float](count: count, repeatedValue: 0)
		sigma = [Float](count: count, repeatedValue: 0)
		logmu = [Float](count: count, repeatedValue: 0)
		logsigma = [Float](count: count, repeatedValue: 0)
		location.getBytes(UnsafeMutablePointer<Void>(mu), length: sizeof(Float)*count)
		scale.getBytes(UnsafeMutablePointer<Void>(sigma), length: sizeof(Float)*count)
		self.dynamicType.logμ(logmu, μ: mu)
		self.dynamicType.logσ(logsigma, σ: sigma)
	}
	internal func shuffle(distribution: StableDistribution) {
		let count: Int = rows * cols
		assert(value.count==count)
		assert(mu.count==count)
		assert(sigma.count==count)
		assert(seed.count==count)
		arc4random_buf(UnsafeMutablePointer<Void>(seed), sizeof(UInt32)*count)
		distribution.dynamicType.rng(value, μ: mu, σ: sigma, ψ: seed)
	}
	internal func xx(η: Float) {
		willChangeValueForKey("location")
		willChangeValueForKey("")
	}
	internal func refresh() {
		self.dynamicType.μ(mu, logμ: logmu)
		self.dynamicType.σ(sigma, logσ: logsigma)
	}
	internal func resize(dim: (rows: Int, cols: Int)) {
		rows = dim.rows
		cols = dim.cols
		location = NSData(bytes: [Float](count: rows*cols, repeatedValue: 0), length: sizeof(Float)*rows*cols)
		scale = NSData(bytes: [Float](count: rows*cols, repeatedValue: 0), length: sizeof(Float)*rows*cols)
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
	internal var logμ: LaObjet {
		return matrix(logmu, rows: rows, cols: cols, deallocator: nil)
	}
	internal var logσ: LaObjet {
		return matrix(logsigma, rows: rows, cols: cols, deallocator: nil)
	}
}
internal extension Arcane {
	internal static func μ(μ: [Float], logμ: [Float]) {
		NSData(bytesNoCopy: UnsafeMutablePointer(logμ), length: sizeof(Float)*logμ.count, freeWhenDone: false)
			.getBytes(UnsafeMutablePointer(μ), length: sizeof(Float)*μ.count)
	}
	internal static func σ(σ: [Float], logσ: [Float]) {
		assert(σ.count==logσ.count)
		let count: Int = min(σ.count, logσ.count)
		vvexpf(UnsafeMutablePointer(σ), logσ, [Int32(count)])
		vDSP_vsadd(σ, 1, [ Float(1)], UnsafeMutablePointer(σ), 1, vDSP_Length(count))
		vvlogf(UnsafeMutablePointer(σ), σ, [Int32(count)])
	}
	internal static func logμ(logμ: [Float], μ: [Float]) {
		NSData(bytesNoCopy: UnsafeMutablePointer(logμ), length: sizeof(Float)*logμ.count, freeWhenDone: false)
			.getBytes(UnsafeMutablePointer(μ), length: sizeof(Float)*μ.count)
	}
	internal static func logσ(logσ: [Float], σ: [Float]) {
		assert(σ.count==logσ.count)
		let count: Int = min(σ.count, logσ.count)
		vvexpf(UnsafeMutablePointer(σ), logσ, [Int32(count)])
		vDSP_vsadd(σ, 1, [-Float(1)], UnsafeMutablePointer<Float>(σ), 1, vDSP_Length(count))
		vvlogf(UnsafeMutablePointer(σ), σ, [Int32(count)])
	}
}