//
//  Config.swift
//  C3
//
//  Created by Kota Nakano on 6/4/16.
//
//

import Foundation
internal class Config {
	static let dispatch: (serial: String, parallel: String) = (serial: "com.organi2e.kn.kotan.C3.dispatch.queue.serial", parallel: "com.organi2e.kn.kotan.C3.dispatch.queue.parallel")
	static let framework: String = NSBundle(forClass: Config.self).infoDictionary!["CFBundleName"]as!String
	static let rng: String = "/dev/urandom"
}