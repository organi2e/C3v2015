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
	@NSManaged internal private(set) var rows: UInt
	@NSManaged internal private(set) var cols: UInt
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
	
		setPrimitiveValue(NSData(data: meandata), forKey: Gauss.meankey)
		assert(meandata.length==sizeof(Float)*Int(rows*cols))
		
		mean = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(meandata.bytes), rows, cols, cols, Config.HINT, nil, Config.ATTR)
		assert(mean.status==LA_SUCCESS&&mean.rows==rows&&mean.cols==cols)
		
		setPrimitiveValue(NSData(data: logvariancedata), forKey: Gauss.logvariancekey)
		assert(logvariancedata.length==sizeof(Float)*Int(rows*cols))
		
		logvariance = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(logvariancedata.bytes), rows, cols, cols, Config.HINT, nil, Config.ATTR)
		assert(logvariance.status==LA_SUCCESS&&logvariance.rows==rows&&logvariance.cols==cols)
	
		variance = la_matrix_from_splat(la_splat_from_float(0, Config.ATTR), rows, cols)
		assert(variance.status==LA_SUCCESS&&variance.rows==rows&&variance.cols==cols)
		
		deviation = la_matrix_from_splat(la_splat_from_float(0, Config.ATTR), rows, cols)
		assert(deviation.status==LA_SUCCESS&&deviation.rows==rows&&deviation.cols==cols)
		
		value = la_matrix_from_splat(la_splat_from_float(0, Config.ATTR), rows, cols)
		assert(value.status==LA_SUCCESS&&value.rows==rows&&value.cols==cols)
		
		refresh()

	}
	
	internal func commit() {
		
		willChangeValueForKey(Gauss.meankey)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(meandata.bytes), cols, mean)
		didChangeValueForKey(Gauss.meankey)
		
		mean = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(meandata.bytes), rows, cols, cols, Config.HINT, nil, Config.ATTR)
		assert(mean.status==LA_SUCCESS&&mean.rows==rows&&mean.cols==cols)
		
		willChangeValueForKey(Gauss.logvariancekey)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(logvariancedata.bytes), cols, logvariance)
		didChangeValueForKey(Gauss.logvariancekey)
		
		logvariance = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(logvariancedata.bytes), rows, cols, cols, Config.HINT, nil, Config.ATTR)
		assert(logvariance.status==LA_SUCCESS&&logvariance.rows==rows&&logvariance.cols==cols)
		
	}
	
	internal func refresh() {
		
		let gauss: la_object_t = normal(rows: rows, cols: cols)
		
		deviation = exp(0.5*logvariance)
		assert(deviation.status==LA_SUCCESS&&deviation.rows==rows&&deviation.cols==cols)
		
		variance = deviation * deviation
		assert(variance.status==LA_SUCCESS&&variance.rows==rows&&variance.cols==cols)
		
		value = mean + deviation * gauss
		assert(value.status==LA_SUCCESS&&value.rows==rows&&value.cols==cols)
		
	}
	
	internal func resize(let rows r: UInt, let cols c: UInt ) {
		
		let count: Int = Int(r*c)
		let meanbuffer: [Float] = [Float](count: count, repeatedValue: 0)
		let logvariancebuffer: [Float] = [Float](count: count, repeatedValue: -log(Float(c)))
		
		rows = r
		cols = c
		
		meandata = NSData(bytes: UnsafePointer<Void>(meanbuffer), length: sizeof(Float)*count)
		assert(meandata.length==sizeof(Float)*Int(r*c))
		
		logvariancedata = NSData(bytes: UnsafePointer<Void>(logvariancebuffer), length: sizeof(Float)*count)
		assert(logvariancedata.length==sizeof(Float)*Int(r*c))
		
		setup()
		
	}
	
}