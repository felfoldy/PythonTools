//
//  Interpreter.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-25.
//

import Foundation
import PyBundle
import PythonKit

public final class Interpreter: PythonInterpreter {
    static let shared = Interpreter()
    
    public var outputStream: OutputStream = DefaultOutputStream()

    private var isInitialized = false
    private let queue = DispatchQueue.global(qos: .userInteractive)

    public static func run(_ script: String) async throws {
        try await shared.run(script)
    }
    
    public static func execute(block: @escaping () throws -> Void) async throws {
        try await shared.execute(block: block)
    }
    
    public static func output(to outputStream: OutputStream) {
        shared.outputStream = outputStream
    }
}

extension Interpreter {
    public func execute(block: @escaping () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if !Interpreter.shared.isInitialized {
                    Interpreter.shared.initializePythonEnvironment()
                }

                // TODO: Add OSSignpost logging.
                do {
                    try block()
                    
                    Interpreter.shared.outputStream.finalize()
                    continuation.resume()
                } catch {
                    Interpreter.shared.outputStream.finalize()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func initializePythonEnvironment() {
        PyBundler.shared.pyInit()
        let sys = Python.import("sys")

        // Inject output stream
        sys.stdout.write = .inject { (str: String) in
            Interpreter.shared.outputStream.receive(output: str)
        }

        sys.stderr.write = .inject { (str: String) in
            Interpreter.shared.outputStream.receive(error: str)
        }
        
        let major = sys.version_info.major
        let minor = sys.version_info.minor
        print("Initialized Python v\(major).\(minor)")

        isInitialized = true
    }
}
