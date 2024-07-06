//
//  InterpreterError.swift
//
//
//  Created by Tibor Felföldy on 2024-06-25.
//

import Python
import PythonKit
import Foundation

public enum InterpreterError: LocalizedError, Equatable {
    case failedToLoadBundle
    
    case unexpected(Error)
    case compilationFailure(String)
    case executionFailure(String)

    public var errorDescription: String? {
        switch self {
        case .failedToLoadBundle:
            "Couldn't load bundle"
            
        case let .compilationFailure(message):
            "Failed to compile:\n\(message)"
            
        case let .executionFailure(message):
            message

        case let .unexpected(error):
            "Unexpected error: \(error.localizedDescription)"
        }
    }

    public static func == (lhs: InterpreterError, rhs: InterpreterError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}
