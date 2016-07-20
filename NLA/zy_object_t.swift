//
//  zy_object_t.swift
//  C³
//
//  Created by Kota Nakano on 7/20/16.
//
//
import Accelerate
import Foundation

public class zy_object_t {
	let once: dispatch_once_t
	let semaphore: dispatch_semaphore_t
	init(let x: la_object_t) {
		once = 0
		semaphore = dispatch_semaphore_create(0)
	}
	func ready() {
		dispatch_once(UnsafeMutablePointer<dispatch_once_t>([once])) {
			dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER)
		}
	}
}