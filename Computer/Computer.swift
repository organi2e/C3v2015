//
//  Factory.swift
//  C³
//
//  Created by Kota Nakano on 6/6/16.
//
//

protocol Computer {
	func sync ( let task: (Void->Void))
	func async ( let task: (Void->Void))
	func enter ( )
	func leave ( )
	func join ( )
	
	func add ( let _: Buffer, let _: Buffer, let _: Buffer )
	func sub ( let _: Buffer, let _: Buffer, let _: Buffer )
	func mul ( let _: Buffer, let _: Buffer, let _: Buffer )
	func div ( let _: Buffer, let _: Buffer, let _: Buffer )
	
	func add ( let _: Buffer, let _: Buffer, let _: Float )
	func sub ( let _: Buffer, let _: Buffer, let _: Float )
	func mul ( let _: Buffer, let _: Buffer, let _: Float )
	func div ( let _: Buffer, let _: Buffer, let _: Float )
	
	func abs ( let _: Buffer, let _: Buffer, let sync: Bool )
	func neg ( let _: Buffer, let _: Buffer, let sync: Bool )
	func sq ( let _: Buffer, let _: Buffer, let sync: Bool )
	func sqrt ( let _: Buffer, let _: Buffer, let sync: Bool )
	
	func exp ( let _: Buffer, let _: Buffer, let sync: Bool )
	func log ( let _: Buffer, let _: Buffer, let sync: Bool )

	func fill( let to _: Buffer, let from: [Float], let sync: Bool )
	func copy( let to _: Buffer, let from: Buffer, let sync: Bool )
	func clear( let _: Buffer, let sync: Bool )
	func clamp( let _: Buffer, let _: Buffer, let _: Float, let _: Float)
	
	func sum ( let x: Buffer ) -> Float
	func dot ( let a: Buffer, let _: Buffer ) -> Float
	func gemv ( let y y: Buffer, let beta: Float, let a: Buffer, let x: Buffer, let alpha: Float, let n: Int, let m: Int, let trans: Bool )
	
	func pdf ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer, let sync: Bool )
	func cdf ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer, let sync: Bool  )
	func normal ( let y: Buffer, let u: Buffer, let s: Buffer, let sync: Bool  )
	func sigmoid ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer, let sync: Bool  )
	
	func newBuffer( let data data: NSData ) -> Buffer
	func newBuffer( let length length: Int ) -> Buffer
	func newBuffer( let buffer buffer: [Float] ) -> Buffer
}
