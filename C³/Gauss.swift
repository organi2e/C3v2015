//
//  Gauss.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Metal
import CoreData
internal class Gauss: NSManagedObject {
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
	override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
}
extension Gauss {
	
	static private let meankey: String = "meandata"
	static private let logvariancekey: String = "logvariancedata"
	
	internal func setup() {
	
		guard let context: Context = managedObjectContext as? Context else {
			fatalError(Context.Error.InvalidContext.description)
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
		guard let context: Context = managedObjectContext as? Context else {
			fatalError(Context.Error.InvalidContext.description)
		}
		context.shuffle(value, deviation: deviation, variance: variance, mean: mean, logvariance: logvariance)
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