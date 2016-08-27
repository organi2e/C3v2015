//
//  Abstract.swift
//  C³
//
//  Created by Kota Nakano on 8/19/16.
//
//
import Accelerate
import Metal
import CoreData

internal class Art: NSManagedObject {
	internal private(set) var ε: [UInt32] = []
	internal private(set) var χ: [Float] = []
	internal private(set) var μ: [Float] = []
	internal private(set) var σ: [Float] = []
	internal private(set) var logμ: [Float] = []
	internal private(set) var logσ: [Float] = []
}

extension Art {
	@NSManaged private var logmu: NSData
	@NSManaged private var logsigma: NSData
	private static let logμkey: String = "logmu"
	private static let logσkey: String = "logsigma"
}

extension Art {
	internal override func awakeFromFetch() {
		super.awakeFromFetch()
		if let context: Context = managedObjectContext as? Context {
			setup(context)
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		}
	}
	override func awakeFromSnapshotEvents(flags: NSSnapshotEventType) {
		super.awakeFromSnapshotEvents(flags)
		if let context: Context = managedObjectContext as? Context {
			setup(context)
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		}
	}
}

extension Art {
	
	internal func setup(let context: Context) {
		
		logμ = Array<Float>(UnsafeBufferPointer<Float>(start: UnsafePointer<Float>(logmu.bytes), count: logmu.length/sizeof(Float)))
		setPrimitiveValue(NSData(bytesNoCopy: &logμ, length: sizeof(Float)*logμ.count, freeWhenDone: false), forKey: self.dynamicType.logμkey)
		
		logσ = Array<Float>(UnsafeBufferPointer<Float>(start: UnsafePointer<Float>(logsigma.bytes), count: logsigma.length/sizeof(Float)))
		setPrimitiveValue(NSData(bytesNoCopy: &logσ, length: sizeof(Float)*logσ.count, freeWhenDone: false), forKey: self.dynamicType.logσkey)
		
		μ = logμ.map { $0 }
		σ = logσ.map { log(1+exp($0)) }
		
		χ = [Float](count: max(μ.count, σ.count), repeatedValue: 0)
		ε = [UInt32](count: max(μ.count, σ.count), repeatedValue: 0)
		
		refresh()
		
	}
	internal func shuffle() {
		willAccess()
		arc4random_buf(UnsafeMutablePointer<Void>(ε), sizeof(UInt32)*ε.count)
		vDSP_vfltu32(ε, 1, &χ, 1, vDSP_Length(min(ε.count, χ.count)))
		vDSP_vsadd(χ, 1, [0.5], &χ, 1, vDSP_Length(χ.count))
		vDSP_vsdiv(χ, 1, [Float(UInt32.max)+1], &χ, 1, vDSP_Length(χ.count))
		vvtanpif(&χ, χ, [Int32(χ.count)])
		didAccess()
	}
	internal func refresh() {
		willAccess()
		NSData(bytesNoCopy: &logμ, length: sizeof(Float)*logμ.count, freeWhenDone: false).getBytes(&μ, length: sizeof(Float)*μ.count)
		vvexpf(&σ, logσ, [Int32(min(σ.count, logσ.count))])
		vDSP_vsadd(σ, 1, [Float(1.0)], &σ, 1, vDSP_Length(σ.count))
		vvlogf(&σ, σ, [Int32(σ.count)])
		didAccess()
	}
	internal func adjust(let μ μ: Float, let σ: Float) {
		willAccess()
		vDSP_vfill([μ], &logμ, 1, vDSP_Length(logμ.count))
		vDSP_vfill([1-exp(-σ)], &logσ, 1, vDSP_Length(logσ.count))
		didAccess()
		refresh()
	}
	internal func resize(let count count: Int) {
		logmu = NSData(bytes: [Float](count: count, repeatedValue: 0), length: sizeof(Float)*count)
		logsigma = NSData(bytes: [Float](count: count, repeatedValue: 0), length: sizeof(Float)*count)
		if let context: Context = managedObjectContext as? Context {
			setup(context)
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		}
	}
	internal func willChange() {
		willChangeValueForKey(self.dynamicType.logμkey)
		willChangeValueForKey(self.dynamicType.logσkey)
	}
	internal func willAccess() {
		willAccessValueForKey(self.dynamicType.logμkey)
		willAccessValueForKey(self.dynamicType.logσkey)
	}
	internal func didChange() {
		didChangeValueForKey(self.dynamicType.logσkey)
		didChangeValueForKey(self.dynamicType.logμkey)
	}
	internal func didAccess() {
		didAccessValueForKey(self.dynamicType.logμkey)
		didAccessValueForKey(self.dynamicType.logσkey)
	}
}
extension Art {
	internal class var shuffleKernel: String { return "artShuffle" }
	internal class var refreshKernel: String { return "artRefresh" }
	internal class var uniformKernel: String { return "artUniform" }
	internal class var adjustKernel: String { return "artAdjust" }
	internal static func uniform(let context context: Context, let χ: MTLBuffer, let bs: Int = 64) {
		let count: Int = χ.length / sizeof(Float)
		let φ: [uint] = [uint](count: 4*bs, repeatedValue: 0)
		arc4random_buf(UnsafeMutablePointer<Void>(φ), sizeof(uint)*φ.count)
		context.newComputeCommand(function: uniformKernel) {
			$0.setBuffer(χ, offset: 0, atIndex: 0)
			$0.setBytes(φ, length: sizeof(uint)*φ.count, atIndex: 1)
			$0.setBytes([uint(13), uint(17), uint(5), uint(count/4)], length: sizeof(uint)*4, atIndex: 2)
			$0.dispatchThreadgroups(MTLSize(width: bs, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func shuffle(let context context: Context, let χ: MTLBuffer, let μ: MTLBuffer, let σ: MTLBuffer, let bs: Int = 64) {
		assert(χ.length==μ.length)
		assert(χ.length==σ.length)
		let count: Int = χ.length / sizeof(Float)
		let φ: [uint] = [uint](count: 4*bs, repeatedValue: 0)
		arc4random_buf(UnsafeMutablePointer<Void>(φ), sizeof(uint)*φ.count)
		context.newComputeCommand(function: uniformKernel) {
			$0.setBuffer(χ, offset: 0, atIndex: 0)
			$0.setBytes(φ, length: sizeof(uint)*φ.count, atIndex: 1)
			$0.setBytes([uint(13), uint(17), uint(5), uint(count/4)], length: sizeof(uint)*4, atIndex: 2)
			$0.dispatchThreadgroups(MTLSize(width: bs, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
		context.newComputeCommand(function: shuffleKernel) {
			$0.setBuffer(χ, offset: 0, atIndex: 0)
			$0.setBuffer(μ, offset: 0, atIndex: 1)
			$0.setBuffer(σ, offset: 0, atIndex: 2)
			$0.setBuffer(χ, offset: 0, atIndex: 3)
			$0.dispatchThreadgroups(MTLSize(width: count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func refresh(let context context: Context, let μ: MTLBuffer, let σ: MTLBuffer, let logμ: MTLBuffer, let logσ: MTLBuffer) {
		assert(μ.length==logμ.length)
		assert(σ.length==logσ.length)
		let count: Int = min(μ.length, σ.length) / sizeof(Float)
		context.newComputeCommand(function: refreshKernel) {
			$0.setBuffer(μ, offset: 0, atIndex: 0)
			$0.setBuffer(σ, offset: 0, atIndex: 1)
			$0.setBuffer(logμ, offset: 0, atIndex: 2)
			$0.setBuffer(logσ, offset: 0, atIndex: 3)
			$0.dispatchThreadgroups(MTLSize(width: count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func adjust(let context context: Context, let logμ: MTLBuffer, let logσ: MTLBuffer, let parameter: (Float, Float)) {
		assert(logμ.length==logσ.length)
		let count: Int = min(logμ.length, logσ.length) / sizeof(Float)
		context.newComputeCommand(function: adjustKernel) {
			$0.setBuffer(logμ, offset: 0, atIndex: 0)
			$0.setBuffer(logσ, offset: 0, atIndex: 1)
			$0.setBytes([parameter.0, parameter.1], length: sizeof(Float)*2, atIndex: 2)
			$0.dispatchThreadgroups(MTLSize(width: count/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
}