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
		let x: CellTests = CellTests()
		x.testSearch0()
		x.testSearch1()
		x.testSearch2()
	}

	func applicationWillTerminate(aNotification: NSNotification) {
		// Insert code here to tear down your application
	}


}


class CellTests {
	static let key: Int = Int(arc4random())
	static let value: [Float] = [arc4random(), arc4random(), arc4random(), arc4random()].map{Float($0)/Float(UInt32.max)}
	func testSearch0() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let cell: Cell = context.newCell(width: 4, label: "test\(CellTests.key)") {
				
				print("init \(CellTests.key)")
				print("\(CellTests.value[0])")
				print("\(CellTests.value[1])")
				print("\(CellTests.value[2])")
				print("\(CellTests.value[3])")
				
				cell[0] = CellTests.value[0]
				cell[1] = CellTests.value[1]
				cell[2] = CellTests.value[2]
				cell[3] = CellTests.value[3]
				
				assert(cell[0]==CellTests.value[0])
				assert(cell[1]==CellTests.value[1])
				assert(cell[2]==CellTests.value[2])
				assert(cell[3]==CellTests.value[3])
				
				context.store() {(_)in
					assertionFailure()
				}
				print("done")
				
			} else {
				assertionFailure()
			}
		} catch let e {
			assertionFailure()
		}
	}
	
	func testSearch1() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let cell: Cell = context.searchCell(label: "test\(CellTests.key)").first {
				
				print("test1")
				print("V:\(cell[0]) vs M:\(CellTests.value[0])")
				print("V:\(cell[1]) vs M:\(CellTests.value[1])")
				print("V:\(cell[2]) vs M:\(CellTests.value[2])")
				print("V:\(cell[3]) vs M:\(CellTests.value[3])")
				
				assert(cell[0]==CellTests.value[0])
				assert(cell[1]==CellTests.value[1])
				assert(cell[2]==CellTests.value[2])
				assert(cell[3]==CellTests.value[3])
				
				cell[0] = CellTests.value[3]
				cell[1] = CellTests.value[2]
				cell[2] = CellTests.value[1]
				cell[3] = CellTests.value[0]
				
				print("V:\(cell[0]) vs M:\(CellTests.value[3])")
				print("V:\(cell[1]) vs M:\(CellTests.value[2])")
				print("V:\(cell[2]) vs M:\(CellTests.value[1])")
				print("V:\(cell[3]) vs M:\(CellTests.value[0])")
				
				assert(cell[0]==CellTests.value[3])
				assert(cell[1]==CellTests.value[2])
				assert(cell[2]==CellTests.value[1])
				assert(cell[3]==CellTests.value[0])
				
				print("STORE")
				
				context.store() {(_)in
					assertionFailure()
				}
			} else {
				print(context.searchCell(label: "test\(CellTests.key)"))
				assertionFailure()
			}
		} catch let e {
			assertionFailure()
		}
	}
	func testSearch2() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent("test.sqlite")
			let context: Context = try Context(storage: url)
			if let cell: Cell = context.searchCell(label: "test\(CellTests.key)").first {
				
				print("test2")
				print("V:\(cell[0]) vs M:\(CellTests.value[3])")
				print("V:\(cell[1]) vs M:\(CellTests.value[2])")
				print("V:\(cell[2]) vs M:\(CellTests.value[1])")
				print("V:\(cell[3]) vs M:\(CellTests.value[0])")
				
				assert(cell[0]==CellTests.value[3])
				assert(cell[1]==CellTests.value[2])
				assert(cell[2]==CellTests.value[1])
				assert(cell[3]==CellTests.value[0])
				
				cell[0] = CellTests.value[3]
				cell[1] = CellTests.value[2]
				cell[2] = CellTests.value[1]
				cell[3] = CellTests.value[0]
				
				context.store() {(_)in
					assertionFailure()
				}
			} else {
				assertionFailure()
			}
		} catch let e {
			assertionFailure()
		}
	}
}
