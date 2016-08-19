//
//  Cauchy.swift
//  C³
//
//  Created by Kota Nakano on 8/19/16.
//
//
import Accelerate
import Metal
import CoreData

internal class Cauchy: Art {
	internal override class var shuffleKernel: String { return "cauchyShuffle" }
}
