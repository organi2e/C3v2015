//
//  Arcane.swift
//  Mac
//
//  Created by Kota Nakano on 8/29/16.
//
//
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
		
		location.getBytes(logmu.bytes, length: logmu.length)
		logscale.getBytes(logsigma.bytes, length: logsigma.length)
		
		setPrimitiveValue(Data(bytesNoCopy: logmu.bytes, length: logmu.length, freeWhenDone: false), forKey: self.dynamicType.locationKey)
		setPrimitiveValue(Data(bytesNoCopy: logsigma.bytes, length: logsigma.length, freeWhenDone: false), forKey: self.dynamicType.logscaleKey)
		
		refresh()
		
		μoptimizer = (managedObjectContext as? Context)?.optimizerFactory(count) ?? μoptimizer
		σoptimizer = (managedObjectContext as? Context)?.optimizerFactory(count) ?? σoptimizer
	}
	private func refresh() {
		guard let context: Context = managedObjectContext as? Context else {
			fatalError(Context.Error.InvalidContext.rawValue)
		}
		let count: Int = rows * cols
		self.dynamicType.refresh(context, μ: mu, σ: sigma, gradlogμ: gradlogmu, gradlogσ: gradlogsigma, logμ: logmu, logσ: logsigma, count: count)
		//self.dynamicType.param(context, param: param, cover: cover, count: count)
		//self.dynamicType.deriv(context, deriv: deriv, param: param, count: count)
		//self.dynamicType.μ(cache.μ, logμ: cache.logμ, count: count)
		//self.dynamicType.σ(cache.σ, logσ: cache.logσ, count: count)
	}
	internal func update(distribution: Distribution.Type, Δμ: LaObjet, Δσ: LaObjet) {
	
		let count: Int = rows * cols
		
		assert(Δμ.count == count)
		assert(Δσ.count == count)
		
		func update() {
			
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
		
			μoptimizer.optimize(
				Δx: LaMatrice(gradlogsigma.bytes, rows: count, cols: 1, deallocator: nil),
				x: LaMatrice(logsigma.bytes, rows: count, cols: 1, deallocator: nil)
			).getBytes(gradlogsigma.bytes)
			
			willChangeValueForKey(self.dynamicType.locationKey)
			( logμ - gradlogμ ).getBytes(logmu.bytes)
			didChangeValueForKey(self.dynamicType.locationKey)
		
			willChangeValueForKey(self.dynamicType.logscaleKey)
			( logσ - gradlogσ ).getBytes(logsigma.bytes)
			didChangeValueForKey(self.dynamicType.logscaleKey)
			
			refresh()
		}
		//sync()
		//dispatch_group_async(group, self.dynamicType.queue, update)
		update()
	}
	internal func adjust(μ μ: Float, σ: Float) {
		
		let count: Int = rows * cols
		
		LaMatrice(μ, rows: rows, cols: cols).getBytes(mu.bytes)
		LaMatrice(σ, rows: rows, cols: cols).getBytes(sigma.bytes)
		
		func schedule() {
			willChangeValueForKey(self.dynamicType.locationKey)
			willChangeValueForKey(self.dynamicType.logscaleKey)
		}
		func complete() {
			didChangeValueForKey(self.dynamicType.locationKey)
			didChangeValueForKey(self.dynamicType.logscaleKey)
		}
		
		

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
/*
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
*/
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
extension Arcane {
	internal class var refreshKernel: String { return "arcaneRefresh" }
	internal static func refresh(context: Context, μ: Buffer, σ: Buffer, gradlogμ: Buffer, gradlogσ: Buffer, logμ: Buffer, logσ: Buffer, count: Int) {
		context.newComputeCommand(sync: true, function: refreshKernel, grid: (count/4, 1, 1), threads: (1, 1, 1)) {
			$0.setBuffer(μ, offset: 0, atIndex: 0)
			$0.setBuffer(σ, offset: 0, atIndex: 1)
			$0.setBuffer(logμ, offset: 0, atIndex: 2)
			$0.setBuffer(logσ, offset: 0, atIndex: 3)
			$0.setBuffer(gradlogμ, offset: 0, atIndex: 4)
			$0.setBuffer(gradlogσ, offset: 0, atIndex: 5)
		}
	}
}