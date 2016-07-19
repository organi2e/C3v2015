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
	
	func add ( let y: Buffer, let _: Buffer, let _: Buffer )
	func sub ( let y: Buffer, let _: Buffer, let _: Buffer )
	func mul ( let y: Buffer, let _: Buffer, let _: Buffer )
	func div ( let y: Buffer, let _: Buffer, let _: Buffer )
	
	func add ( let y: Buffer, let _: Buffer, let _: Float )
	func sub ( let y: Buffer, let _: Buffer, let _: Float )
	func mul ( let y: Buffer, let _: Buffer, let _: Float )
	func div ( let y: Buffer, let _: Buffer, let _: Float )
	
	func abs ( let y: Buffer, let _: Buffer )
	func neg ( let y: Buffer, let _: Buffer )
	func sq ( let y: Buffer, let _: Buffer )
	func sqrt ( let y: Buffer, let _: Buffer )
	
	func exp ( let y: Buffer, let _: Buffer )
	func log ( let y: Buffer, let _: Buffer )

	func fill( let y: Buffer, let _: Float)
	func clamp( let y: Buffer, let _: Buffer, let _: Float, let _: Float)
	
	func sum ( let x: Buffer ) -> Float
	func dot ( let a: Buffer, let _: Buffer ) -> Float
	func gemv ( let y y: Buffer, let beta: Float, let a: Buffer, let x: Buffer, let alpha: Float, let n: Int, let m: Int, let trans: Bool )
	
	func pdf ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer, let sync: Bool )
	func cdf ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer, let sync: Bool  )
	func normal ( let y: Buffer, let u: Buffer, let s: Buffer, let sync: Bool  )
	func sigmoid ( let y: Buffer, let x: Buffer, let u: Buffer, let s: Buffer, let sync: Bool  )
	
	func test ();
	func newBuffer( let data data: NSData ) -> Buffer
	func newBuffer( let length length: Int ) -> Buffer
}
