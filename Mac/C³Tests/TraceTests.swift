//
//  EdgeTests.swift
//  Mac
//
//  Created by Kota Nakano on 6/7/16.
//
//
import Foundation
import XCTest
@testable import C3
class TraceTests: XCTestCase {
	static let file: String = "test.sqlite"
	static let label: [String] = (0..<6).map {(_)in "\(arc4random())"}
	func test0Insert() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent(TraceTests.file)
			let context: Context = try Context(storage: url)
			var last: Cell?
			TraceTests.label.forEach {
				if let cell: Cell = context.newCell(width: 10, label: $0) {
					if let last: Cell = last {
						context.chainCell(output: last, input: cell)
					}
					last = cell
				}
			}
			context.store {
				XCTFail(String($0))
			}
		} catch let e {
			XCTFail(String(e))
		}
	}
	func test1Fetch() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent(TraceTests.file)
			let context: Context = try Context(storage: url)
			var targets: Set<String> = Set<String>(TraceTests.label)
			if let label: String = TraceTests.label.first, cell: Cell = context.searchCell(label: label).last {
				cell.iTrace {
					XCTAssert(targets.remove($0.label) != nil)
				}
				XCTAssert(targets.isEmpty)
			} else {
				XCTFail()
			}
		} catch let e {
			XCTFail(String(e))
		}
	}
	func test2Remove() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent(TraceTests.file)
			let context: Context = try Context(storage: url)
			var labels: [String] = TraceTests.label
			if let label: String = labels.popLast(), via: Cell = context.searchCell(label: label).last {
				if let label: String = labels.popLast(), dst: Cell = context.searchCell(label: label).last {
					context.unchainCell(output: dst, input: via)
				} else {
					XCTFail("not found")
				}
			} else {
				XCTFail("not found")
			}
			context.store {
				XCTFail(String($0))
			}
		} catch let e {
			XCTFail(String(e))
		}
	}
	func test3Fetch() {
		do {
			let url: NSURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true).URLByAppendingPathComponent(TraceTests.file)
			let context: Context = try Context(storage: url)
			var targets: Set<String> = Set<String>(TraceTests.label)
			if let label: String = TraceTests.label.first, cell: Cell = context.searchCell(label: label).last {
				cell.iTrace {
					XCTAssert(targets.remove($0.label) != nil)
				}
				XCTAssert(targets.first==TraceTests.label.last)
			} else {
				XCTFail()
			}
		} catch let e {
			XCTFail(String(e))
		}
	}
}