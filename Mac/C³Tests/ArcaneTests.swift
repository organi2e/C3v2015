//
//  ArcaneTest.swift
//  Mac
//
//  Created by Kota Nakano on 8/30/16.
//
//

import XCTest
@testable import C3
class ArcaneTest: XCTestCase {
	let context: Context = try!Context()
	func uf(u: [Float]) -> Float{
		return (
			(u[0]+16)*(u[0]+16) +
			(u[1]+32)*(u[1]+32)
		)
	}
	func ug(u: [Float]) -> [Float] {
		return [
			2*(u[0]+16),
			2*(u[1]+32)
		]
	}
	func sf(s: [Float]) -> Float{
		return (
			(s[0]-4)*(s[0]-4) +
			(s[1]-8)*(s[1]-8)
		)
	}
	func sg(s: [Float]) -> [Float] {
		return [
			2*(s[0]-4),
			2*(s[1]-8)
		]
	}
	func testUpdate() {
		
		let rows: Int = 2
		let cols: Int = 1
		
		let a: Arcane! = context.new()

		a.resize(rows: rows, cols: cols)
		a.adjust(μ: 2, σ: 2)
		
		(0..<64).forEach {(_)in
			let gu: [Float] = ug(Array(a.cache.μ))
			let gs: [Float] = sg(Array(a.cache.σ))
			let Δμ: LaObjet = LaMatrice(gu, rows: rows, cols: cols, deallocator: nil)
			let Δσ: LaObjet = LaMatrice(gs, rows: rows, cols: cols, deallocator: nil)
			a.update(Δμ: Δμ, Δσ: Δσ)
			
			print(Array(a.cache.μ))
			print(Array(a.cache.σ))
		}
		
		print(Array(a.cache.μ))
		print(Array(a.cache.σ))
		
	}
}
