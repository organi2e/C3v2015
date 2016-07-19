//
//  mtlComputerTest.swift
//  C³
//
//  Created by Kota Nakano on 7/19/16.
//
//

import XCTest
@testable import Computer

class mtlComputerTests: cpuComputerTests {
	override func implementation() -> Computer {
		guard let device: MTLDevice = MTLCreateSystemDefaultDevice() else {
			let message: String = "No metal device found"
			XCTFail(message)
			fatalError(message)
		}
		do {
			return try mtlComputer(device: device)
		} catch {
			let message: String = "No mtlComputer created"
			XCTFail(message)
			fatalError(message)
		}
	}
}
