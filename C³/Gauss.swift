//
//  Gauss.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Accelerate
import Metal
import CoreData

internal class Gauss: NSManagedObject {
	internal private(set) var value: MTLBuffer!
	internal private(set) var mean: MTLBuffer!
	internal private(set) var variance: MTLBuffer!
	internal private(set) var uniform: MTLBuffer!
	internal private(set) var logmean: MTLBuffer!
	internal private(set) var logvariance: MTLBuffer!
}

extension Gauss {
	@NSManaged internal private(set) var rows: Int
	@NSManaged internal private(set) var cols: Int
	@NSManaged private var logmeandata: NSData
	@NSManaged private var logvariancedata: NSData
	@nonobjc internal static let logmeankey: String = "logmeandata"
	@nonobjc internal static let logvariancekey: String = "logvariancedata"
}

extension Gauss {
	internal override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
}

extension Gauss {
	
	internal func setup() {
	
		if let context: Context = managedObjectContext as? Context {
			
			value = context.newBuffer(length: sizeof(Float)*rows*cols)
			uniform = context.newBuffer(length: sizeof(UInt16)*rows*cols)
			
			mean = context.newBuffer(length: sizeof(Float)*rows*cols)
			variance = context.newBuffer(length: sizeof(Float)*rows*cols)
			
			logmean = context.newBuffer(data: logmeandata)
			logvariance = context.newBuffer(data: logvariancedata)
			
			arc4random_buf(uniform.contents(), uniform.length)
			
			refresh()
			shuffle()
			
			setPrimitiveValue(NSData(bytesNoCopy: logmean.contents(), length: logmean.length, freeWhenDone: false), forKey: Gauss.logmeankey)
			setPrimitiveValue(NSData(bytesNoCopy: logvariance.contents(), length: logvariance.length, freeWhenDone: false), forKey: Gauss.logvariancekey)
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
		
	}
	internal func shuffle() {
		if let context: Context = managedObjectContext as? Context {
			Gauss.shuffle(context: context, value: value, mean: mean, variance: variance, uniform: uniform, rows: rows, cols: cols)
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
	}
	internal func refresh() {
		if let context: Context = managedObjectContext as? Context {
			Gauss.refresh(context: context, mean: mean, variance: variance, logmean: logmean, logvariance: logvariance, rows: rows, cols: cols)
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
	}
	internal func adjust(let mean adjust_mean: Float, let variance adjust_variance: Float) {
		if let context: Context = managedObjectContext as? Context {
			let adjust_logmean: Float = log(2.0/(adjust_mean+1.0)-1.0)
			let adjust_logvariance: Float = log(adjust_variance)
			
			assert(!isnan(adjust_logmean))
			assert(!isinf(adjust_logmean))
			
			assert(!isnan(adjust_logvariance))
			assert(!isinf(adjust_logvariance))
			
			Gauss.adjust(context: context, logmean: logmean, logvariance: logvariance, newLogmean: adjust_logmean, newLogvariance: adjust_logvariance, rows: rows, cols: cols)
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
		refresh()
	}
	internal func resize(let rows r: Int, let cols c: Int ) {
		
		rows = r
		cols = c
		
		logmeandata = NSData(bytes: [Float](count: rows*cols, repeatedValue: 0), length: sizeof(Float)*rows*cols)
		assert(logmeandata.length==sizeof(Float)*Int(rows*cols))
		
		logvariancedata = NSData(bytes: [Float](count: rows*cols, repeatedValue: 0), length: sizeof(Float)*rows*cols)
		assert(logvariancedata.length==sizeof(Float)*Int(rows*cols))
		
		setup()
		
		
	}
}
extension Gauss {
	internal static func refresh(let context context: Context, let mean: MTLBuffer, let variance: MTLBuffer, let logmean: MTLBuffer, let logvariance: MTLBuffer, let rows: Int, let cols: Int) {
		context.newComputeCommand(function: "gaussRefresh") {
			$0.setBuffer(mean, offset: 0, atIndex: 0)
			$0.setBuffer(variance, offset: 0, atIndex: 1)
			$0.setBuffer(logmean, offset: 0, atIndex: 2)
			$0.setBuffer(logvariance, offset: 0, atIndex: 3)
			$0.dispatchThreadgroups(MTLSize(width: (rows*cols-1)/4+1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func shuffle(let context context: Context, let value: MTLBuffer, let mean: MTLBuffer, let variance: MTLBuffer, let uniform: MTLBuffer, let rows: Int, let cols: Int) {
		context.newComputeCommand(function: "gaussShuffle", complete: {context.performBlock{arc4random_buf(uniform.contents(), uniform.length)}}) {
			$0.setBuffer(value, offset: 0, atIndex: 0)
			$0.setBuffer(mean, offset: 0, atIndex: 1)
			$0.setBuffer(variance, offset: 0, atIndex: 2)
			$0.setBuffer(uniform, offset: 0, atIndex: 3)
			$0.dispatchThreadgroups(MTLSize(width: (rows*cols-1)/4+1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func adjust(let context context: Context, let logmean: MTLBuffer, let logvariance: MTLBuffer, let newLogmean: Float, let newLogvariance: Float, let rows: Int, let cols: Int) {
		context.newComputeCommand(function: "gaussAdjust") {
			$0.setBuffer(logmean, offset: 0, atIndex: 0)
			$0.setBuffer(logvariance, offset: 0, atIndex: 1)
			$0.setBytes([newLogmean, newLogvariance], length: 2*sizeof(Float), atIndex: 2)
			$0.dispatchThreadgroups(MTLSize(width: (rows*cols-1)/4+1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
}