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
	internal private(set) var value: MTLBuffer!
	internal private(set) var uniform: MTLBuffer!
	internal private(set) var mu: MTLBuffer!
	internal private(set) var sigma: MTLBuffer!
	internal private(set) var logmu: MTLBuffer!
	internal private(set) var logsigma: MTLBuffer!
}

extension Art {
	@NSManaged internal private(set) var rows: Int
	@NSManaged internal private(set) var cols: Int
	@NSManaged private var logmudata: NSData
	@NSManaged private var logsigmadata: NSData
	@nonobjc internal static let logmukey: String = "logmudata"
	@nonobjc internal static let logsigmakey: String = "logsigmadata"
}

extension Art {
	internal override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
	override func awakeFromSnapshotEvents(flags: NSSnapshotEventType) {
		super.awakeFromSnapshotEvents(flags)
		setup()
	}
}

extension Art {
	
	internal func setup() {
		
		if let context: Context = managedObjectContext as? Context {
			
			value = context.newBuffer(length: sizeof(Float)*rows*cols, options: .StorageModePrivate)
			uniform = context.newBuffer(length: sizeof(UInt16)*rows*cols, options: .CPUCacheModeWriteCombined)
			
			mu = context.newBuffer(length: sizeof(Float)*rows*cols, options: .StorageModePrivate)
			sigma = context.newBuffer(length: sizeof(Float)*rows*cols, options: .StorageModePrivate)
			
			logmu = context.newBuffer(data: logmudata, options: .CPUCacheModeDefaultCache)
			setPrimitiveValue(NSData(bytesNoCopy: logmu.contents(), length: logmu.length, freeWhenDone: false), forKey: Art.logmukey)
			
			logsigma = context.newBuffer(data: logsigmadata, options: .CPUCacheModeDefaultCache)
			setPrimitiveValue(NSData(bytesNoCopy: logsigma.contents(), length: logsigma.length, freeWhenDone: false), forKey: Art.logsigmakey)
			
			refresh()
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
		
	}
	internal func shuffle() {
		if let context: Context = managedObjectContext as? Context where 0 < rows && 0 < cols {
			self.dynamicType.shuffle(context: context, value: value, mu: mu, sigma: sigma, uniform: uniform, rows: rows, cols: cols)
			
		} else {
			assertionFailure("\(Context.Error.InvalidContext.rawValue) or rows:\(rows), cols: \(cols)")
			
		}
	}
	internal func refresh() {
		if let context: Context = managedObjectContext as? Context where 0 < rows && 0 < cols {
			self.dynamicType.refresh(context: context, mu: mu, sigma: sigma, logmu: logmu, logsigma: logsigma, rows: rows, cols: cols)
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
	}
	internal func adjust(let mu mu: Float, let sigma: Float) {
		if let context: Context = managedObjectContext as? Context where 0 < rows && 0 < cols {
			self.dynamicType.adjust(context: context, logmu: logmu, logsigma: logsigma, parameter: (mu, sigma), rows: rows, cols: cols)
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
		refresh()
	}
	internal func resize(let rows r: Int, let cols c: Int ) {
		
		rows = r
		cols = c
		
		logmudata = NSData(bytes: [Float](count: rows*cols, repeatedValue: 0), length: sizeof(Float)*rows*cols)
		logsigmadata = NSData(bytes: [Float](count: rows*cols, repeatedValue: 0), length: sizeof(Float)*rows*cols)
		
		setup()
		
	}
	internal func dump(let label: String? = nil) {
		if let context: Context = managedObjectContext as? Context where 0 < rows && 0 < cols {
			
			let logm: la_object_t = context.toLAObject(logmu, rows: rows, cols: cols)
			let logs: la_object_t = context.toLAObject(logsigma, rows: rows, cols: cols)
			
			let cache: [Float] = [Float](count: rows*cols, repeatedValue: 0)
			
			if let label: String = label {
				print(label)
			}
			
			context.join()
			
			print(Art.logmukey)
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(cols), logm)
			(0..<rows).forEach {
				print(cache[$0*cols..<($0+1)*cols])
			}
			
			la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), la_count_t(cols), logs)
			print(Art.logsigmakey)
			(0..<rows).forEach {
				print(cache[$0*cols..<($0+1)*cols])
			}
			
		} else {
			
		}
	}
}
extension Art {
	internal class var shuffleKernel: String { return "artShuffle" }
	internal class var refreshKernel: String { return "artRefresh" }
	internal class var adjustKernel: String { return "artAdjust" }
	internal class func shuffle(let context context: Context, let value: MTLBuffer, let mu: MTLBuffer, let sigma: MTLBuffer, let uniform: MTLBuffer, let rows: Int, let cols: Int) {
		assert(rows*cols%4==0)
		arc4random_buf(uniform.contents(), uniform.length)
		context.newComputeCommand(function: shuffleKernel) {
			$0.setBuffer(value, offset: 0, atIndex: 0)
			$0.setBuffer(mu, offset: 0, atIndex: 1)
			$0.setBuffer(sigma, offset: 0, atIndex: 2)
			$0.setBuffer(uniform, offset: 0, atIndex: 3)
			$0.dispatchThreadgroups(MTLSize(width: rows*cols/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func refresh(let context context: Context, let mu: MTLBuffer, let sigma: MTLBuffer, let logmu: MTLBuffer, let logsigma: MTLBuffer, let rows: Int, let cols: Int) {
		assert(rows*cols%4==0)
		context.newComputeCommand(function: refreshKernel) {
			$0.setBuffer(mu, offset: 0, atIndex: 0)
			$0.setBuffer(sigma, offset: 0, atIndex: 1)
			$0.setBuffer(logmu, offset: 0, atIndex: 2)
			$0.setBuffer(logsigma, offset: 0, atIndex: 3)
			$0.dispatchThreadgroups(MTLSize(width: rows*cols/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func adjust(let context context: Context, let logmu: MTLBuffer, let logsigma: MTLBuffer, let parameter: (Float, Float), let rows: Int, let cols: Int) {
		assert(rows*cols%4==0)
		context.newComputeCommand(function: adjustKernel) {
			$0.setBuffer(logmu, offset: 0, atIndex: 0)
			$0.setBuffer(logsigma, offset: 0, atIndex: 1)
			$0.setBytes([parameter.0, parameter.1], length: sizeof(Float)*2, atIndex: 2)
			$0.dispatchThreadgroups(MTLSize(width: rows*cols/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
}