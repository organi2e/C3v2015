//
//  Config.swift
//  C3
//
//  Created by Kota Nakano on 6/4/16.
//
//

import Foundation
import Accelerate

internal struct Config {
	static let bundle: NSBundle = NSBundle(forClass: Context.self)
	static let identifier: String = {
		guard let identifier: String = Config.bundle.bundleIdentifier else {
			fatalError("")
		}
		return identifier
	}()
	static let framework: String = {
		guard let dictionary: [String: AnyObject] = Config.bundle.infoDictionary, framework: String = dictionary["CFBundleName"] as? String else {
			fatalError("")
		}
		return framework
	}()
	static let coredata: (name: String, ext: String) = (name: "C³", ext: "momd")
	static let dispatch: (serial: String, parallel: String) = (
		serial: "\(Config.identifier).dispatch.queue.serial",
		parallel: "\(Config.identifier).dispatch.queue.parallel"
	)
}
