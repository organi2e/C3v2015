//
//  Config.swift
//  C3
//
//  Created by Kota Nakano on 6/4/16.
//
//

import Foundation
internal class Config {
	static let bundle: NSBundle = NSBundle(forClass: Config.self)
	static let identifier: String = {(_)->String in
		guard let identifier: String = Config.bundle.bundleIdentifier else {
			fatalError("Bundle Broken")
		}
		return identifier
	}()
	static let framework: String = {
		guard let dictionary: [String: AnyObject] = Config.bundle.infoDictionary, framework: String = dictionary["CFBundleName"] as? String else {
			fatalError("Bundle Broken")
		}
		return framework
	}()
	static let metal: (name: String, ext: String) = (name: "default", ext: "metallib")
	static let dispatch: (serial: String, parallel: String) = (
		serial: "\(Config.identifier).dispatch.queue.serial",
		parallel: "\(Config.identifier).dispatch.queue.parallel"
	)
}

