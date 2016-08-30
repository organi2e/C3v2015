//
//  ConjugateGradient.swift
//  C³
//
//  Created by Kota Nakano on 8/30/16.
//
//
import Foundation
internal class ConjugateGradient {
	let p: [Float]
	let g: [Float]
	var P: LaObjet {
		return LaMatrice(p, rows: p.count, cols: 1, deallocator: nil)
	}
	var prevG: LaObjet {
		return LaMatrice(g, rows: g.count, cols: 1, deallocator: nil)
	}
	init(dim: Int){
		p = [Float](count: dim, repeatedValue: 0)
		g = [Float](count: dim, repeatedValue: 0)
	}
	func update(g G: LaObjet, x: LaObjet) -> LaObjet {
		defer {
			G.getBytes(g)
		}
		if let
			m: Float = inner_product(G, G-prevG).array.first,
			M: Float = inner_product(prevG, prevG).array.first
		where
			1e-20 < abs(m) && 1e-20 < abs(M)
		{
			(max(0,m/M) * P - G).getBytes(p)
			return -1 * P
		} else {
			
			return G
		}
	}
}