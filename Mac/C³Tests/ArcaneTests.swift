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
			(u[0]+3)*(u[0]+3) +
			(u[1]+8)*(u[1]+8)
		)
	}
	func ug(u: [Float]) -> [Float] {
		return [
			2*(u[0]+3),
			2*(u[1]+8)
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
		
		context.optimizerFactory = Adam.factory()
		let a: Arcane! = context.new()

		a.resize(rows: rows, cols: cols)
		a.adjust(μ: 2, σ: 2)
		
		(0..<64).forEach {(_)in
			
			print(a.μ.array)
			print(a.σ.array)
			
			let gu: [Float] = ug(a.μ.array)
			let gs: [Float] = sg(a.σ.array)
			let Δμ: LaObjet = LaMatrice(gu, rows: rows, cols: cols, deallocator: nil)
			let Δσ: LaObjet = LaMatrice(gs, rows: rows, cols: cols, deallocator: nil)
			a.update(FalseDistribution.self, Δμ: Δμ, Δσ: Δσ)
			
		}
		
		print(a.μ.array)
		print(a.σ.array)
		
	}
}
