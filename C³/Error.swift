//
//  Error.swift
//  C3
//
//  Created by Kota Nakano on 6/4/16.
//
//

import Foundation
enum Error: ErrorType {
	enum System: String, ErrorType, CustomStringConvertible {
		case FailObjectDecode = "Object is not correctly decoded"
		case InvalidOperation = "Invalid operation"
		case InvalidContext = "Invalid context"
		var description: String {
			return rawValue
		}
	}
	enum Metal: String, ErrorType, CustomStringConvertible {
		case NoLibraryFound = "No Library Found"
		case NoDeviceFound = "No Device Found"
		var description: String {
			return rawValue
		}
	}
	enum CoreData: String, ErrorType, CustomStringConvertible {
		case ModelNotFound = "Core Data Model Not Found"
		case ModelNotAvailable = "Core Data Model Not Available"
		case Model(model: String) = "desc"
		enum AnyError: ErrorType {
			case error(message: String)
		}
		var description: String {
			return rawValue
		}
	}
	case AnyError(option: String)
}



