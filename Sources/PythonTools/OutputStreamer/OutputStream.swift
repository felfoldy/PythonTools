//
//  PythonOutputStreamer.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-26.
//

import Foundation

/// Python output stream protocol.
public protocol OutputStream: AnyObject {
    var outputBuffer: [String] { get set }
    var errorBuffer: [String] { get set }

    /// Signals the end of the code execution to finalize the buffers.
    /// - Parameters:
    ///   - id: ID of the CompilableCode.
    ///   - executionTime: Time in nanoseconds.
    func finalize(codeId: UUID, executionTime: UInt64)

    /// Called after an expression is evaluated to handle the result.
    /// - Parameter result: The result of the evaluated expression.
    func evaluation(result: String)

    func clear()
}

extension OutputStream {
    func receive(output: String) {
        outputBuffer.append(output)
        print(output, terminator: "")
    }

    func receive(error: String) {
        errorBuffer.append(error)
        print(error, terminator: "")
    }

    public var output: String {
        outputBuffer
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var errorMessage: String {
        errorBuffer
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
