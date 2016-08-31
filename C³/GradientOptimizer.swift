//
//  GradientOptimizer.swift
//  C³
//
//  Created by Kota Nakano on 8/31/16.
//
//
protocol GradientOptimizer {
	func optimize(Δx Δx: LaObjet, x: LaObjet) -> LaObjet
}