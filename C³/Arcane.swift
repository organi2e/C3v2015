//
//  Arcane.swift
//  Mac
//
//  Created by Kota Nakano on 8/29/16.
//
//
import Accelerate
internal class Arcane: ManagedObject {

	private var value: Buffer! = nil
	private var mu: Buffer! = nil
	private var sigma: Buffer! = nil
	private var logmu: Buffer! = nil
	private var logsigma: Buffer! = nil
	private var gradlogmu: Buffer! = nil
	private var gradlogsigma: Buffer! = nil
	
	//private var optimizer: GradientOptimizer = SGD()
	private var μoptimizer: GradientOptimizer = SGD()
	private var σoptimizer: GradientOptimizer = SGD()
	
	private var refreshKernel: Pipeline?
	
}
internal extension Arcane {
	@NSManaged private var location: Data
	@NSManaged private var logscale: Data
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
	internal override func awakeFromSnapshotEvents(flags: SnapshotEventType) {
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
		let length: Int = sizeof(Float) * ( ( count + 3 ) / 4 ) * 4
		
		value = context.newBuffer(length: length, options: .StorageModeShared)
		mu = context.newBuffer(length: length, options: .StorageModeShared)
		sigma = context.newBuffer(length: length, options: .StorageModeShared)
		logmu = context.newBuffer(length: length, options: .StorageModeShared)
		logsigma = context.newBuffer(length: length, options: .StorageModeShared)
		gradlogmu = context.newBuffer(length: length, options: .StorageModeShared)
		gradlogsigma = context.newBuffer(length: length, options: .StorageModeShared)
		
		refreshKernel = try?context.newPipeline("arcaneRefresh")
		
		location.getBytes(logmu.bytes, length: logmu.length)
		logscale.getBytes(logsigma.bytes, length: logsigma.length)
		
		setPrimitiveValue(Data(bytesNoCopy: logmu.bytes, length: logmu.length, freeWhenDone: false), forKey: self.dynamicType.locationKey)
		setPrimitiveValue(Data(bytesNoCopy: logsigma.bytes, length: logsigma.length, freeWhenDone: false), forKey: self.dynamicType.logscaleKey)
		
		μoptimizer = context.optimizerFactory(count)
		σoptimizer = context.optimizerFactory(count)
		
	}
	internal func refresh(compute compute: Compute, distribution: Distribution) {
		let count: Int = rows * cols
		willAccessValueForKey(self.dynamicType.locationKey)
		willAccessValueForKey(self.dynamicType.logscaleKey)
		if let refreshKernel: Pipeline = refreshKernel {
			compute.setComputePipelineState(refreshKernel)
			compute.setBuffer(mu, offset: 0, atIndex: 0)
			compute.setBuffer(sigma, offset: 0, atIndex: 1)
			compute.setBuffer(gradlogmu, offset: 0, atIndex: 2)
			compute.setBuffer(gradlogsigma, offset: 0, atIndex: 3)
			compute.setBuffer(logmu, offset: 0, atIndex: 4)
			compute.setBuffer(logsigma, offset: 0, atIndex: 5)
			compute.dispatch(grid: ((count+3)/4, 1, 1), threads: (1, 1, 1))
		} else {
			assertionFailure()
		}
		didAccessValueForKey(self.dynamicType.logscaleKey)
		didAccessValueForKey(self.dynamicType.locationKey)
		
		distribution.rng(compute, χ: value, μ: mu, σ: sigma)
	}
	internal func update(distribution: Distribution, Δμ: LaObjet, Δσ: LaObjet) {
	
		let count: Int = rows * cols
		
		assert(Δμ.count == count)
		assert(Δσ.count == count)
		
		distribution.Δμ(
			Δ: LaMatrice(gradlogmu.bytes, rows: Δμ.rows, cols: Δμ.cols, deallocator: nil) * Δμ,
			μ: LaMatrice(mu.bytes, rows: Δμ.rows, cols: Δμ.cols, deallocator: nil))
		.getBytes(gradlogmu.bytes)
		
		μoptimizer.optimize(
			Δx: LaMatrice(gradlogmu.bytes, rows: count, cols: 1, deallocator: nil),
			x: LaMatrice(logmu.bytes, rows: count, cols: 1, deallocator: nil)
		).getBytes(gradlogmu.bytes)
		
		distribution.Δσ(
			Δ: LaMatrice(gradlogsigma.bytes, rows: Δσ.rows, cols: Δσ.cols, deallocator: nil) * Δσ,
			σ: LaMatrice(logsigma.bytes, rows: Δσ.rows, cols: Δσ.cols, deallocator: nil))
		.getBytes(gradlogsigma.bytes)
	
		σoptimizer.optimize(
			Δx: LaMatrice(gradlogsigma.bytes, rows: count, cols: 1, deallocator: nil),
			x: LaMatrice(logsigma.bytes, rows: count, cols: 1, deallocator: nil)
		).getBytes(gradlogsigma.bytes)
		
		willChangeValueForKey(self.dynamicType.locationKey)
		( logμ - gradlogμ ).getBytes(logmu.bytes)
		didChangeValueForKey(self.dynamicType.locationKey)
	
		willChangeValueForKey(self.dynamicType.logscaleKey)
		( logσ - gradlogσ ).getBytes(logsigma.bytes)
		didChangeValueForKey(self.dynamicType.logscaleKey)

	}
	internal func adjust(μ m: Float, σ s: Float) {
		
		let count: Int = rows * cols
		
		LaMatrice(m, rows: rows, cols: cols).getBytes(mu.bytes)
		LaMatrice(s, rows: rows, cols: cols).getBytes(sigma.bytes)
		
		willChangeValueForKey(self.dynamicType.locationKey)
		μ.getBytes(logmu.bytes)
		didChangeValueForKey(self.dynamicType.locationKey)
		
		willChangeValueForKey(self.dynamicType.logscaleKey)
		vvexpf(logsigma.bytes, sigma.bytes, [Int32(count)])
		vDSP_vsadd(logsigma.bytes, 1, [Float(-1)], logsigma.bytes, 1, vDSP_Length(count))
		vvlogf(logsigma.bytes, logsigma.bytes, [Int32(count)])
		didChangeValueForKey(self.dynamicType.logscaleKey)
		
	}
	internal func resize(rows r: Int, cols c: Int) {
		
		rows = r
		cols = c

		let count: Int = rows * cols
		
		location = Data(bytes: [Float](count: count, repeatedValue: 0), length: sizeof(Float)*count)
		logscale = Data(bytes: [Float](count: count, repeatedValue: 0), length: sizeof(Float)*count)
		
		setup()
	}
}
extension Arcane: RandomNumberGeneratable {
	internal var χ: LaObjet {
		return LaMatrice(value.bytes, rows: rows, cols: cols, deallocator: nil)
	}
	internal var μ: LaObjet {
		return LaMatrice(mu.bytes, rows: rows, cols: cols, deallocator: nil)
	}
	internal var σ: LaObjet {
		return LaMatrice(sigma.bytes, rows: rows, cols: cols, deallocator: nil)
	}
	private var logμ: LaObjet {
		return LaMatrice(logmu.bytes, rows: rows, cols: cols, deallocator: nil)
	}
	private var logσ: LaObjet {
		return LaMatrice(logsigma.bytes, rows: rows, cols: cols, deallocator: nil)
	}
	private var gradlogμ: LaObjet {
		return LaMatrice(gradlogmu.bytes, rows: rows, cols: cols, deallocator: nil)
	}
	private var gradlogσ: LaObjet {
		return LaMatrice(gradlogsigma.bytes, rows: rows, cols: cols, deallocator: nil)
	}
	internal func shuffle(distribution: Distribution.Type) {
		
		//sync()
		//dispatch_group_async(group, self.dynamicType.queue, shuffle)
	}
}
