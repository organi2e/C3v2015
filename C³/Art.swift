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

extension UInt8 {
	var bitPattern: [Bool] {
		return(0..<8).map { 1 == 1 & self >> $0 }
	}
	var oneHotEncoding: [Bool] {
		let cmp: UInt16 = UInt16(self)
		return(0..<256).map { $0 == cmp }
	}
}

internal class Art: NSManagedObject {
	internal private(set) var χ: MTLBuffer!
	internal private(set) var μ: MTLBuffer!
	internal private(set) var σ: MTLBuffer!
	internal private(set) var logμ: MTLBuffer!
	internal private(set) var logσ: MTLBuffer!
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
		
		logμ = context.newBuffer(data: logmu, options: .CPUCacheModeDefaultCache)
		setPrimitiveValue(NSData(bytesNoCopy: logμ.contents(), length: logμ.length, freeWhenDone: false), forKey: self.dynamicType.logμkey)
		
		logσ = context.newBuffer(data: logsigma, options: .CPUCacheModeDefaultCache)
		setPrimitiveValue(NSData(bytesNoCopy: logσ.contents(), length: logσ.length, freeWhenDone: false), forKey: self.dynamicType.logσkey)
		
		μ = context.newBuffer(length: logμ.length, options: .StorageModePrivate)
		σ = context.newBuffer(length: logσ.length, options: .StorageModePrivate)
		
		χ = context.newBuffer(length: max(logμ.length, logσ.length), options: .StorageModePrivate)
		
		refresh()
		
	}
	internal func shuffle() {
		if let context: Context = managedObjectContext as? Context {
			willAccess()
			self.dynamicType.shuffle(context: context, χ: χ, μ: μ, σ: σ)
			didAccess()
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		}
	}
	internal func refresh() {
		if let context: Context = managedObjectContext as? Context {
			willAccess()
			self.dynamicType.refresh(context: context, μ: μ, σ: σ, logμ: logμ, logσ: logσ)
			didAccess()
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		}
	}
	internal func adjust(let μ μ: Float, let σ: Float) {
		if let context: Context = managedObjectContext as? Context {
			willAccess()
			self.dynamicType.adjust(context: context, logμ: logμ, logσ: logσ, parameter: (μ, σ))
			didAccess()
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		}
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
	/*
	internal func dump(let label: String? = nil) {
		if let context: Context = managedObjectContext as? Context where 0 < rows && 0 < cols {
			
			let logm: la_object_t = context.toLAObject(logμ, rows: rows, cols: cols)
			let logs: la_object_t = context.toLAObject(logσ, rows: rows, cols: cols)
			
			let cache: [Float] = [Float](count: rows*cols, repeatedValue: 0)
			
			if let label: String = label {
				print(label)
			}
			
			context.join()
			
			print(Art.logμkey)
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(cols), logm)
			(0..<rows).forEach {
				print(cache[$0*cols..<($0+1)*cols])
			}
			
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(cols), logs)
			print(Art.logσkey)
			(0..<rows).forEach {
				print(cache[$0*cols..<($0+1)*cols])
			}
			
		} else {
			
		}
	}
	*/
}
extension Art {
	internal class var shuffleKernel: String { return "artShuffle" }
	internal class var refreshKernel: String { return "artRefresh" }
	internal class var uniformKernel: String { return "artUniform" }
	internal class var adjustKernel: String { return "artAdjust" }
	internal static func cauchy(χ: [Float]) {
		let array: [UInt32] = [UInt32](count: χ.count, repeatedValue: 0)
		arc4random_buf(UnsafeMutablePointer<Void>(array), sizeof(UInt32)*array.count)
		vDSP_vfltu32(array, 1, UnsafeMutablePointer<Float>(χ), 1, vDSP_Length(χ.count))
	}
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