//
//  Error.swift
//  C3
//
//  Created by Kota Nakano on 6/4/16.
//
//

import Foundation
enum MetalError: String, ErrorType, CustomStringConvertible {
	case DeviceNotFound = "Metal Device Not Found"
	case LibraryNotAvailable = "Metal Library Not Available"
	var description: String {
		return rawValue
	}
}
enum CoreDataError: String, ErrorType, CustomStringConvertible {
	case ModelNotFound = "Core Data Model Not Found"
	case ModelNotAvailable = "Core Data Model Not Available"
	var description: String {
		return rawValue
	}
}
enum SystemError: String, ErrorType, CustomStringConvertible {
	case RNGNotFound = "RNG device is not opened"
	case FailObjectDecode = "Object is not correctly decoded"
	case InvalidOperation = "Invalid operation"
	var description: String {
		return rawValue
	}
}
