//
//  Buffer.swift
//  C³
//
//  Created by Kota Nakano on 9/8/16.
//
//
import Metal

public typealias Buffer = MTLBuffer

internal extension Buffer {
	var bytes: UnsafeMutablePointer<Float> {
		return UnsafeMutablePointer<Float>(contents())
	}
	var vecteur: LaObjet {
		return LaMatrice(contents(), rows: length/sizeof(Float), cols: 1, deallocator: nil)
	}
}
