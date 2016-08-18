//
//  MNIST.swift
//  OSX
//
//  Created by Kota Nakano on 5/23/16.
//
//
import Metal
import Foundation
public class Image {
	public let rows: Int
	public let cols: Int
	public let label: UInt8
	public let pixel: [UInt8]
	private init(let pixel: [UInt8], let label: UInt8, let rows: Int, let cols: Int) {
		self.label = label
		self.pixel = pixel
		self.rows = rows
		self.cols = cols
	}
	private static func load(let image image: String, let label: String) -> [Image] {
		var result: [Image] = []
		func dataFromBundle(let path: String) -> NSData? {
			var result: NSData?
			if let url: NSURL = NSBundle(forClass: Image.self).URLForResource(path, withExtension: nil), data: NSData = NSData(contentsOfURL: url) {
				result = data
			}
			return result
		}
		if let data: NSData = dataFromBundle(image) where sizeof(UInt32)*4<data.length {
			let(headdata, bodydata) = data.split(sizeof(UInt32)*4)
			let head: [Int] = headdata.toArray().map{Int(UInt32(bigEndian: $0))}
			let length: Int = head[1]
			let rows: Int = head[2]
			let cols: Int = head[3]
			let pixelsbody: [UInt8] = bodydata.toArray()
			if length * rows * cols == pixelsbody.count, let data: NSData = dataFromBundle(label) where sizeof(UInt32) * 2 < data.length {
				let(headdata, bodydata) = data.split(sizeof(UInt32) * 2)
				let head: [Int] = headdata.toArray().map{Int(UInt32(bigEndian: $0))}
				let length: Int = head[1]
				let labelsbody: [UInt8] = bodydata.toArray()
				if length == labelsbody.count {
					let pixels: [[UInt8]] = pixelsbody.chunk(rows*cols)
					let labels: [UInt8] = labelsbody
					result = zip(pixels, labels).map{Image(pixel: $0, label: $1, rows: rows, cols: cols)}
				}
			}
		}
		return result
	}
	public static let train: [Image] = Image.load(image: "train-images.idx3-ubyte", label: "train-labels.idx1-ubyte")
	public static let t10k: [Image] = Image.load(image: "t10k-images.idx3-ubyte", label: "t10k-labels.idx1-ubyte")
}
extension NSData {
	func split(let cursor: Int) -> (NSData, NSData){
		return (subdataWithRange(NSRange(location: 0, length: cursor)), subdataWithRange(NSRange(location: cursor, length: length - cursor)))
	}
	func toArray<T>() -> [T] {
		return Array<T>(UnsafeBufferPointer<T>(start: UnsafePointer<T>(bytes), count: length/sizeof(T)))
	}
}
extension Array {
	func chunk(let width: Int) -> [[Element]] {
		return 0.stride(to: count, by: width).map{Array(self[$0..<$0.advancedBy(width, limit: count)])}
	}
}
