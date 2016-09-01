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
	func testUpdate() {
		
		let rows: Int = 4
		let cols: Int = 8
		
		let a: Arcane! = context.new()
		
		let Δμ: LaObjet = LaMatrice(1.0, rows: rows, cols: cols)
		let Δσ: LaObjet = LaMatrice(1.0, rows: rows, cols: cols)
		
		a.resize(rows: rows, cols: cols)
		a.adjust(μ: 2, σ: 4)
		
		print(a.μ.array)
		print(a.σ.array)
		
		(0..<4096).forEach {(_)in
			a.update(1/1024.0, Δμ: Δμ, Δσ: Δσ)
		}

		print(a.μ.array)
		print(a.σ.array)
		
	}
}
