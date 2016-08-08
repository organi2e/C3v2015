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
	var value: MTLBuffer!
	var mean: MTLBuffer!
	var variance: MTLBuffer!
	var logvariance: MTLBuffer!
}

extension Gauss {
	@NSManaged internal private(set) var rows: Int
	@NSManaged internal private(set) var cols: Int
	@NSManaged private var meandata: NSData
	@NSManaged private var logvariancedata: NSData

}

extension Gauss {
	internal override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}

}

extension Gauss {
	
	static private let meankey: String = "meandata"
	static private let logvariancekey: String = "logvariancedata"
	
	internal func setup() {
	
		if let context: Context = managedObjectContext as? Context {
			
			value = context.newBuffer(length: sizeof(Float)*rows*cols)
			variance = context.newBuffer(length: sizeof(Float)*rows*cols)
			
			mean = context.newBuffer(data: meandata)
			logvariance = context.newBuffer(data: logvariancedata)
			
			refresh()
			
			setPrimitiveValue(NSData(bytesNoCopy: mean.contents(), length: mean.length, freeWhenDone: false), forKey: Gauss.meankey)
			setPrimitiveValue(NSData(bytesNoCopy: logvariance.contents(), length: logvariance.length, freeWhenDone: false), forKey: Gauss.logvariancekey)
			
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
		
	}
	
	internal func refresh() {
		
		if let context: Context = managedObjectContext as? Context {
			
			let semaphore: dispatch_semaphore_t = dispatch_semaphore_create(0)
			let cache: MTLBuffer = context.newBuffer(length: sizeof(UInt16)*rows*cols)
			
			context.performBlock {
				arc4random_buf(cache.contents(), cache.length)
				dispatch_semaphore_signal(semaphore)
			}
			
			let gauss_value: MTLBuffer = value
			let gauss_variance: MTLBuffer = variance
			let gauss_mean: MTLBuffer = mean
			let gauss_logvariance: MTLBuffer = logvariance
			
			let group: MTLSize = MTLSize(width: (rows*cols-1)/4+1, height: 1, depth: 1)
			let local: MTLSize = MTLSize(width: 1, height: 1, depth: 1)
			
			context.newComputeCommand(function: "gaussShuffle", schedule: {dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)}, complete: {cache.setPurgeableState(.Empty)}) {
				
				$0.setBuffer(gauss_value, offset: 0, atIndex: 0)
				$0.setBuffer(gauss_variance, offset: 0, atIndex: 1)
				$0.setBuffer(gauss_mean, offset: 0, atIndex: 2)
				$0.setBuffer(gauss_logvariance, offset: 0, atIndex: 3)
				$0.setBuffer(cache, offset: 0, atIndex: 4)
				
				$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
				
			}
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
		
	}
	
	internal func resize(let rows r: Int, let cols c: Int ) {
		
		rows = r
		cols = c
		
		meandata = NSData(bytes: [Float](count: rows*cols, repeatedValue: 0), length: sizeof(Float)*rows*cols)
		assert(meandata.length==sizeof(Float)*Int(rows*cols))
		
		logvariancedata = NSData(bytes: [Float](count: rows*cols, repeatedValue: 0), length: sizeof(Float)*rows*cols)
		assert(logvariancedata.length==sizeof(Float)*Int(rows*cols))
		
		setup()
		
	}
	
	internal func adjust(let mean mean: Float, let variance: Float) {
		adjustMean(mean: [Float](count: Int(rows*cols), repeatedValue: mean))
		adjustVariance(variance: [Float](count: Int(rows*cols), repeatedValue: variance))
	}
	
	internal func adjustMean(let mean buffer: [Float]) {
		if let context: Context = managedObjectContext as? Context {
			let gauss: MTLBuffer = mean
			let cache: MTLBuffer = context.newBuffer(buffer)
			context.newBlitCommand(complete: {cache.setPurgeableState(.Empty)}) {
				$0.copyFromBuffer(cache, sourceOffset: 0, toBuffer: gauss, destinationOffset: 0, size: min(gauss.length, cache.length))
			}
			
		} else {
			assertionFailure()
			
		}
	}
	
	internal func adjustVariance(let variance buffer: [Float]) {
	
		if let context: Context = managedObjectContext as? Context {
			
			let cache: MTLBuffer = context.newBuffer(buffer)
			let gauss: MTLBuffer = logvariance
			
			let group: MTLSize = MTLSize(width: (rows*cols-1)/4+1, height: 1, depth: 1)
			let local: MTLSize = MTLSize(width: 1, height: 1, depth: 1)

			context.newComputeCommand(function: "log", complete: {cache.setPurgeableState(.Empty)}) {
				$0.setBuffer(gauss, offset: 0, atIndex: 0)
				$0.setBuffer(cache, offset: 0, atIndex: 1)
				$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
			}
			
		} else {
			assertionFailure()
		
		}
	}
	
}