//
//  Gauss.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Accelerate
import CoreData
internal class Gauss: NSManagedObject {
	var value: la_object_t = la_splat_from_float(0, Config.ATTR)
	var mean: la_object_t = la_splat_from_float(0, Config.ATTR)
	var deviation: la_object_t = la_splat_from_float(0, Config.ATTR)
	var variance: la_object_t = la_splat_from_float(0, Config.ATTR)
	var logvariance: la_object_t = la_splat_from_float(0, Config.ATTR)
}
extension Gauss {
	@NSManaged private var rows: UInt
	@NSManaged private var cols: UInt
	@NSManaged private var meandata: NSData
	@NSManaged private var logvariancedata: NSData
	@NSManaged private var alter: Alter
}
extension Gauss {
	override func awakeFromFetch() {
		super.awakeFromFetch()
		
		assert(meandata.length==sizeof(Float)*Int(rows*cols))
		assert(logvariancedata.length==sizeof(Float)*Int(rows*cols))
		
		
	}
}
extension Gauss {
	internal func setup() {
		
		setPrimitiveValue(NSData(data: meandata), forKey: "meandata")
		setPrimitiveValue(NSData(data: logvariancedata), forKey: "logvariancedata")
		
		assert(meandata.length==sizeof(Float)*Int(rows*cols))
		mean = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(meandata.bytes), rows, cols, cols, Config.HINT, nil, Config.ATTR)
		assert(mean.status==LA_SUCCESS&&mean.rows==rows&&mean.cols==cols)
		
		assert(logvariancedata.length==sizeof(Float)*Int(rows*cols))
		logvariance = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(logvariancedata.bytes), rows, cols, cols, Config.HINT, nil, Config.ATTR)
		assert(logvariance.status==LA_SUCCESS&&logvariance.rows==rows&&logvariance.cols==cols)
		
	}
	internal func commit() {
		willChangeValueForKey("meandata")
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(meandata.bytes), cols, mean)
		didChangeValueForKey("meandata")
		
		willChangeValueForKey("logvariancedata")
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(logvariancedata.bytes), cols, logvariance)
		didChangeValueForKey("logvariancedata")
	}
	internal func shuffle() {
		deviation = exp(0.5*logvariance)
		variance = deviation * deviation
		value = mean + deviation * normal(rows: rows, cols: cols)
	}
}