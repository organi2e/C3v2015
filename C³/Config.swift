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
	static let HINT: la_hint_t = la_hint_t(LA_NO_HINT)
	static let ATTR: la_attribute_t = la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)
}
extension dispatch_group_t {
	func wait(let time: dispatch_time_t = DISPATCH_TIME_FOREVER) {
		dispatch_group_wait(self, time)
	}
	func enter() {
		dispatch_group_enter(self)
	}
	func leave() {
		dispatch_group_leave(self)
	}
}
extension dispatch_semaphore_t {
	func lock(let time: dispatch_time_t = DISPATCH_TIME_FOREVER) {
		dispatch_semaphore_wait(self, time)
	}
	func unlock() {
		dispatch_semaphore_signal(self)
	}
}
