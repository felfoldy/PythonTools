//
//  PythonOutputStreamer.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-26.
//

import Foundation

@MainActor
public protocol OutputStream: AnyObject {
    @MainActor
    var outputBuffer: [String] { get set }
    @MainActor
    var errorBuffer: [String] { get set }

    /// Signals the end of the code execution to finalize the buffers.
    /// - Parameters:
    ///   - id: ID of the CompilableCode.
    ///   - executionTime: Time in nanoseconds.
    @MainActor
    func finalize(codeId: UUID, executionTime: UInt64)

    /// Called after an expression is evaluated to handle the result.
    /// - Parameter result: The result of the evaluated expression.
    @MainActor
    func evaluation(result: String)

    @MainActor
    func clear()
}

extension OutputStream {
    @MainActor
    func receive(output: String) {
        outputBuffer.append(output)
        print(output, terminator: "")
    }
    
    @MainActor
    func receive(error: String) {
        errorBuffer.append(error)
        print(error, terminator: "")
    }
    
    @MainActor
    public var output: String {
        outputBuffer
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    @MainActor
    public var errorMessage: String {
        errorBuffer
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
