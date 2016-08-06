//
//  Gauss.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Metal
import CoreData
public class Gauss: NSManagedObject {
	var value: MTLBuffer!
	var mean: MTLBuffer!
	var deviation: MTLBuffer!
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
	public override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
}
extension Gauss {
	
	static private let meankey: String = "meandata"
	static private let logvariancekey: String = "logvariancedata"
	
	internal func setup() {
	
		guard let context: Context = managedObjectContext as? Context else {
			fatalError(Context.Error.InvalidContext.rawValue)
		}
		
		value = context.newBuffer(length: sizeof(Float)*rows*cols)
		deviation = context.newBuffer(length: sizeof(Float)*rows*cols)
		variance = context.newBuffer(length: sizeof(Float)*rows*cols)
		
		mean = context.newBuffer(data: meandata)
		logvariance = context.newBuffer(data: logvariancedata)

		if let mean: MTLBuffer = mean {
			setPrimitiveValue(NSData(bytesNoCopy: mean.contents(), length: mean.length, freeWhenDone: false), forKey: Gauss.meankey)
		}
		if let logvariance: MTLBuffer = logvariance {
			setPrimitiveValue(NSData(bytesNoCopy: logvariance.contents(), length: logvariance.length, freeWhenDone: false), forKey: Gauss.logvariancekey)
		}
		
	}
	
	internal func refresh() {
		if let context: Context = managedObjectContext as? Context {
			
			let semaphore: dispatch_semaphore_t = dispatch_semaphore_create(0)
			let cache: MTLBuffer = context.newBuffer(length: sizeof(Float)*rows*cols)
			
			context.performBlock {
				arc4random_buf(cache.contents(), cache.length)
				dispatch_semaphore_signal(semaphore)
			}
			
			let gauss_value: MTLBuffer = value
			let gauss_deviation: MTLBuffer = deviation
			let gauss_variance: MTLBuffer = variance
			let gauss_mean: MTLBuffer = mean
			let gauss_logvariance: MTLBuffer = logvariance
			
			let group: MTLSize = MTLSize(width: (rows-1)/4+1, height: 1, depth: 1)
			let local: MTLSize = MTLSize(width: (cols-1)/4+1, height: 1, depth: 1)
			
			context.newComputeCommand(function: "gaussShuffle", schedule: {dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)}, complete: {cache.setPurgeableState(.Empty)}) {
				$0.setBuffer(gauss_value, offset: 0, atIndex: 0)
				$0.setBuffer(gauss_deviation, offset: 0, atIndex: 1)
				$0.setBuffer(gauss_variance, offset: 0, atIndex: 2)
				$0.setBuffer(gauss_mean, offset: 0, atIndex: 3)
				$0.setBuffer(gauss_logvariance, offset: 0, atIndex: 4)
				$0.setBuffer(cache, offset: 0, atIndex: 5)
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
		
		//Xavier's initial value
		logvariancedata = NSData(bytes: [Float](count: rows*cols, repeatedValue: -log(0.5*Float(cols))), length: sizeof(Float)*rows*cols)
		assert(logvariancedata.length==sizeof(Float)*Int(rows*cols))
		
		setup()
		
	}
	
}