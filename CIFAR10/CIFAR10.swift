//
//  CIFAR-10.swift
//  C³
//
//  Created by Kota Nakano on 8/18/16.
//
//
import Metal
import Foundation
public class CIFAR10 {
	public struct Image {
		public let label: UInt8
		public let r: [UInt8]
		public let g: [UInt8]
		public let b: [UInt8]
		public var bgra: [UInt8] {
			let count: Int = rows * cols
			assert(r.count==count)
			assert(g.count==count)
			assert(b.count==count)
			return(0..<count).map { [b[$0], g[$0], r[$0], 255] }.reduce([]) { $0.0 + $0.1 }
		}
		public var meta: String {
			let index: Int = Int(label)
			return index < CIFAR10.meta.count ? CIFAR10.meta[index] : ""
		}
		public var cols: Int {
			return CIFAR10.cols
		}
		public var rows: Int {
			return CIFAR10.rows
		}
		private init(let label: UInt8, let r: [UInt8], let g: [UInt8], let b: [UInt8]) {
			self.label = label
			self.r = r
			self.g = g
			self.b = b
		}
	}
	private static let rows: Int = 32
	private static let cols: Int = 32
	private static var bundle: NSBundle {
		return NSBundle(forClass: CIFAR10.self)
	}
	private static func batch(let path: String, let ext: String = "bin") -> [Image] {
		if let url: NSURL = bundle.URLForResource(path, withExtension: ext), data: NSData = NSData(contentsOfURL: url) {
			let count: Int = rows * cols
			let data: [UInt8] = data.toArray()
			assert( data.count % (1+3*count) == 0 )
			return data.chunk(1+3*count).map {
				let label: UInt8 = $0[0]
				let r: [UInt8] = Array<UInt8>($0[1+0*count..<1+1*count])
				let g: [UInt8] = Array<UInt8>($0[1+1*count..<1+2*count])
				let b: [UInt8] = Array<UInt8>($0[1+2*count..<1+3*count])
				return Image(label: label, r: r, g: g, b: b)
			}
		}
		return []
	}
	private static func meta(let path: String, let ext: String = "txt") -> [String] {
		if let url: NSURL = bundle.URLForResource(path, withExtension: ext), text: String = try?String(contentsOfURL: url, encoding: NSASCIIStringEncoding) {
			return text.componentsSeparatedByString("\n")
		}
		return []
	}
	public static let batch1: [Image] = CIFAR10.batch("data_batch_1")
	public static let batch2: [Image] = CIFAR10.batch("data_batch_2")
	public static let batch3: [Image] = CIFAR10.batch("data_batch_3")
	public static let batch4: [Image] = CIFAR10.batch("data_batch_4")
	public static let batch5: [Image] = CIFAR10.batch("data_batch_5")
	public static let test: [Image] = CIFAR10.batch("test_batch")
	public static let meta: [String] = CIFAR10.meta("batches.meta")
}
extension NSData {
	func toArray<T>() -> [T] {
		return Array<T>(UnsafeBufferPointer<T>(start: UnsafePointer<T>(bytes), count: length/sizeof(T)))
	}
}
extension Array {
	func chunk(let width: Int) -> [[Element]] {
		return 0.stride(to: count, by: width).map{Array(self[$0..<$0.advancedBy(width, limit: count)])}
	}
}

