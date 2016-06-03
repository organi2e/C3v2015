//
//  Cell.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

import CoreData
import Metal
public class Cell: NSManagedObject {
	@NSManaged var label: String
	@NSManaged var width: Int
	@NSManaged var recur: Bool
	@NSManaged var bias: NSData
	@NSManaged var input: Set<Edge>
	@NSManaged var output: Set<Edge>
}
extension Cell {
	public func chain () {
		print(label)
		if input.isEmpty {
		
		} else {
			input.forEach {
				$0.input.chain()
			}
			
		}
	}
}
extension Cell {
	private func allocate() {
	
	}
}
extension Context {
	public func newCell ( let width width: Int, let label: String = "", let recur: Bool = false, let input: [Cell] = [] ) -> Cell? {
		let cell: Cell? = new()
		if let cell: Cell = cell {
			cell.width = width
			cell.label = label
			cell.recur = recur
			cell.bias = NSData(bytes: [Float](count: width, repeatedValue: 0.0), length: sizeof(Float)*width)
			
			input.forEach {
				let input: Cell = $0
				if let edge: Edge = new() {
					edge.input = input
					edge.gain = NSData(bytes: [Float](count: cell.width*input.width, repeatedValue: 0.0), length: sizeof(Float)*cell.width*input.width)
					cell.input.insert(edge)
				}
			}
		}
		return cell
	}
	public func searchCell( let width width: Int? = nil, let label: String? = nil ) -> [Cell] {
		var attribute: [String: AnyObject] = [:]
		if let width: Int = width {
			attribute [ "width" ] = width
		}
		if let label: String = label {
			attribute [ "label" ] = label
		}
		let cell: [Cell] = fetch ( attribute )
		return cell
	}
}
