//
//  Config.swift
//  C3
//
//  Created by Kota Nakano on 6/4/16.
//
//

import Foundation
internal struct Config {
	static let bundle: NSBundle = NSBundle(forClass: Context.self)
	static let identifier: String = Config.bundle.bundleIdentifier!
	static let framework: String = Config.bundle.infoDictionary!["CFBundleName"]as!String
	static let coredata: (name: String, ext: String) = (name: "C³", ext: "momd")
	static let metal: (name: String, ext: String) = (name: "default", ext: "metallib")
	static let dispatch: (serial: String, parallel: String) = (
		serial: "\(Config.identifier).dispatch.queue.serial",
		parallel: "\(Config.identifier).dispatch.queue.parallel"
	)
	static let rngurl: NSURL = NSURL(fileURLWithPath: "/dev/urandom")
}
internal protocol CoreDataSharedMetal {
	func setup ( )
}
protocol Network {
	func clear ( )
	func chain ( let callback: ( Cell -> Void ) )
	func train ( let eps: Float )
}
public enum Platform: String {
	case GPU = "GPU"
	case CPU = "CPU"
}
