//
//  PythonOutputStreamer.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-26.
//

public protocol OutputStream: AnyObject {
    var outputBuffer: [String] { get set }
    var errorBuffer: [String] { get set }

    /// Execution time.
    /// - Parameter time: time in nanoseconds.
    @MainActor
    func execution(time: UInt64)
    
    /// Called when an expression is evaluated to handle the result.
    /// - Parameter result: The result of the evaluated expression.
    @MainActor
    func evaluation(result: String)
    
    @MainActor
    func finalize()
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
