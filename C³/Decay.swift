//
//  Gauss.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Metal
import CoreData
internal class Decay: NSManagedObject {
	private var λ: MTLBuffer!
	private var logλ: MTLBuffer!
}
extension Decay {
	@NSManaged private var loglambda: NSData
	@NSManaged private var cell: Cell
}
extension Decay {
	override func awakeFromFetch() {
		super.awakeFromFetch()
		setup()
	}
	override func awakeFromSnapshotEvents(flags: NSSnapshotEventType) {
		super.awakeFromSnapshotEvents(flags)
		setup()
	}
}
extension Decay {
	
	@nonobjc internal static let logλkey: String = "loglambda"
	
	private func setup() {
		if let context: Context = managedObjectContext as? Context {
			let width: Int = cell.width
			λ = context.newBuffer(length: sizeof(Float)*width, options: .StorageModePrivate)
			logλ = context.newBuffer(data: loglambda, options: .CPUCacheModeDefaultCache)
			setPrimitiveValue(NSData(bytesNoCopy: logλ.contents(), length: logλ.length, freeWhenDone: false), forKey: self.dynamicType.logλkey)
		} 
		refresh()
		
	}
	
	//internal func correct(let eps eps: Float, let delta: la_object_t, let value: la_object_t, let dydv: la_object_t, let feedback: la_object_t? = nil) {
		/*
		var gradientmean: la_object_t = la_diagonal_matrix_from_vector(value, 0)
		
		gradientmean = gradientmean + la_matrix_product(la_diagonal_matrix_from_vector(lambda, 0), gradient)
		
		if let feedback: la_object_t = feedback {
			gradientmean = gradientmean + la_matrix_product(feedback, la_matrix_product(la_diagonal_matrix_from_vector(dydv, 0), gradient))
		}
		
		gradient = gradientmean.dup
		
		siglambda = siglambda + eps * ( lambda ) * ( 1.0 - lambda ) * la_matrix_product(la_transpose(delta), gradient).reshape(rows: rows, cols: cols)
		assert(siglambda.status==LA_SUCCESS&&siglambda.rows==rows&&siglambda.cols==cols)
*/
	//}
	
	internal func refresh() {
//		lambda = sigmoid(siglambda)
	}
	
	internal func commit() {
		/*
		willChangeValueForKey(Decay.siglambdadatakey)
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(siglambdadata.bytes), cols, siglambda)
		didChangeValueForKey(Decay.siglambdadatakey)
		
		siglambda = la_matrix_from_float_buffer(UnsafeMutablePointer<Float>(siglambdadata.bytes), rows, cols, cols, Config.HINT, Config.ATTR)
		assert(siglambda.status==LA_SUCCESS&&siglambda.rows==rows&&siglambda.cols==cols)
		*/
	}
	
	internal func resize(let rows r: UInt, let cols c: UInt ) {
		/*
		let count: Int = Int(r*c)
		let siglambdabuffer: [Float] = [Float](count: count, repeatedValue: 0)
		
		rows = r
		cols = c
		
		siglambdadata = NSData(bytes: siglambdabuffer, length: sizeof(Float)*count)
		assert(siglambdadata.length==sizeof(Float)*Int(r*c))
		
		setup()
		*/
	}
	
}
extension Context {
	internal func newDecay(let width width: UInt) throws -> Decay {
		guard let decay: Decay = new() else {
			throw Error.CoreData.InsertionFails(entity: Decay.className())
		}
		decay.resize(rows: width, cols: 1)
		return decay
	}
}