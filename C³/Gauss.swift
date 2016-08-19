//
//  Gauss.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Accelerate
import Metal
import CoreData

internal class Gauss: Art {
	internal override class var shuffleKernel: String { return "gaussShuffle" }
	var mean:MTLBuffer { return mu }
	var variance: MTLBuffer { return sigma }
	var logmean: MTLBuffer { return logmu }
	var logvariance: MTLBuffer { return logsigma }
	static var logmeankey: String = ""
	static var logvariancekey: String = ""
}
