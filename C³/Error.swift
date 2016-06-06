//
//  Error.swift
//  C3
//
//  Created by Kota Nakano on 6/4/16.
//
//

import Foundation
enum MetalError: String, ErrorType {
	case DeviceNotFound = "Metal Device Not Found"
	case LibraryNotAvailable = "Metal Library Not Available"
}
enum CoreDataError: String, ErrorType {
	case ModelNotFound = "Core Data Model Not Found"
	case ModelNotAvailable = "Core Data Model Not Available"
}
enum SystemError: String, ErrorType {
	case RNGNotFound = "RNG device is not opened"
	case FailObjectDecode = "Object is not correctly decoded"
	case InvalidOperation = "Invalid operation"
}
