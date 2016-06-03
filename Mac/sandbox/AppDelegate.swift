//
//  AppDelegate.swift
//  sandbox
//
//  Created by Kota Nakano on 6/3/16.
//
//

import Cocoa
import C3
import MNIST
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	
	func applicationDidFinishLaunching(aNotification: NSNotification) {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
			let ct: ctx = try ctx(storage: url.URLByAppendingPathComponent("sandbox.sqlite"))
			
			let context: Context = try Context(storage: url.URLByAppendingPathComponent("sandbox.sqlite"))
			if
				context.searchCell(label: "O").isEmpty,
			let
				I: Cell = context.newCell(width: 16, label: "I"),
				H: Cell = context.newCell(width: 16, label: "H", input: [I]),
				_: Cell = context.newCell(width: 16, label: "O", input: [H]) {
				print("created")
				try context.save()
			}
			if let O: Cell = context.searchCell(label: "O").first {
				O.chain()
			}
		} catch let e as NSError {
			print(e)
		}
		
		// Insert code here to initialize your application
	}

	func applicationWillTerminate(aNotification: NSNotification) {
		// Insert code here to tear down your application
	}


}

