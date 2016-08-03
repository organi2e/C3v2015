//
//  Gauss.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Accelerate
import CoreData
internal class Decay: NSManagedObject {
	var gradient: la_object_t = la_splat_from_float(0, Config.ATTR)
	var lambda: la_object_t = la_splat_from_float(0, Config.ATTR)
	var siglambda: la_object_t = la_splat_from_float(0, Config.ATTR)
}
extension Decay {
	@NSManaged internal private(set) var rows: UInt
	@NSManaged internal private(set) var cols: UInt
	@NSManaged private var siglambdadata: NSData
}
extension Decay {
	override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
}
extension Decay {
	
	static private let siglambdadatakey: String = "siglambdadata"
	
	internal func setup() {
		
		setPrimitiveValue(NSData(data: siglambdadata), forKey: Decay.siglambdadatakey)
		assert(siglambdadata.length==sizeof(Float)*Int(rows*cols))
		
		siglambda = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(siglambdadata.bytes), rows, cols, cols, Config.HINT, nil, Config.ATTR)
		assert(siglambda.status==LA_SUCCESS&&siglambda.rows==rows&&siglambda.cols==cols)
		
		lambda = la_matrix_from_splat(la_splat_from_float(0, Config.ATTR), rows, cols)
		assert(lambda.status==LA_SUCCESS&&lambda.rows==rows&&lambda.cols==cols)
		
		gradient = la_matrix_from_splat(la_splat_from_float(0, Config.ATTR), rows, rows * cols)
		assert(gradient.status==LA_SUCCESS&&gradient.rows==rows&&gradient.cols==rows * cols)
		
		refresh()
		
	}
	
	internal func correct(let eps eps: Float, let delta error: la_object_t) {
		siglambda = siglambda + eps * la_matrix_product(la_transpose(error), gradient).reshape(rows: rows, cols: cols)
		assert(siglambda.status==LA_SUCCESS&&siglambda.rows==rows&&siglambda.cols==cols)
	}
	
	internal func refresh() {
		lambda = sigmoid(siglambda)
	}
	
	internal func commit() {
		
		willChangeValueForKey(Decay.siglambdadatakey)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(siglambdadata.bytes), cols, siglambda)
		didChangeValueForKey(Decay.siglambdadatakey)
		
		siglambda = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(siglambdadata.bytes), rows, cols, cols, Config.HINT, nil, Config.ATTR)
		assert(siglambda.status==LA_SUCCESS&&siglambda.rows==rows&&siglambda.cols==cols)
		
		gradient = gradient.dup
		assert(gradient.status==LA_SUCCESS&&gradient.rows==rows&&gradient.cols==rows*cols)
		
	}
	
	internal func resize(let rows r: UInt, let cols c: UInt ) {
		
		let count: Int = Int(r*c)
		let siglambdabuffer: [Float] = [Float](count: count, repeatedValue: 0)
		
		rows = r
		cols = c
		
		siglambdadata = NSData(bytes: UnsafePointer<Void>(siglambdabuffer), length: sizeof(Float)*count)
		assert(siglambdadata.length==sizeof(Float)*Int(r*c))
		
		setup()
		
	}
	
}
extension Context {
	internal func newDecay(let width width: UInt) throws -> Decay {
		guard let decay: Decay = new() else {
			throw Error.EntityError.InsertionFails(entity: Decay.className())
		}
		decay.resize(rows: width, cols: 1)
		return decay
	}
}