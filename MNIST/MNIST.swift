//
//  MNIST.swift
//  OSX
//
//  Created by Kota Nakano on 5/23/16.
//
//
import Foundation
public class Image {
	public let rows: Int
	public let columns: Int
	public let label: UInt8
	public let pixel: [Float]
	private init(let pixel: [Float], let label: UInt8, let rows: Int, let columns: Int) {
		self.label = label
		self.pixel = pixel
		self.rows = rows
		self.columns = columns
	}
	private static func load(let image: String, let label: String) -> [Image] {
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
			let columns: Int = head[3]
			let pixelsbody: [UInt8] = bodydata.toArray()
			if length*rows*columns == pixelsbody.count, let data: NSData = dataFromBundle(label) where sizeof(UInt32)*2<data.length {
				let(headdata, bodydata) = data.split(sizeof(UInt32)*2)
				let head: [Int] = headdata.toArray().map{Int(UInt32(bigEndian: $0))}
				let length: Int = head[1]
				let labelsbody: [UInt8] = bodydata.toArray()
				if length == labelsbody.count {
					let pixels: [[UInt8]] = pixelsbody.chunk(rows*columns)
					let labels: [UInt8] = labelsbody
					result = zip(pixels, labels).map{Image(pixel: $0.map{Float($0)}, label: $1, rows: rows, columns: columns)}
				}
			}
		}
		return result
	}
	public static let train: [Image] = Image.load("train-images.idx3-ubyte", label: "train-labels.idx1-ubyte")
	public static let t10k: [Image] = Image.load("t10k-images.idx3-ubyte", label: "t10k-labels.idx1-ubyte")
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
