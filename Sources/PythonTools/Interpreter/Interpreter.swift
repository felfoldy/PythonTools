//
//  Interpreter.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-25.
//

import Foundation
import PyBundle
import PythonKit
import Python

public final class Interpreter: PythonInterpreter {
    static let shared = Interpreter()
    
    @MainActor
    public var outputStream: OutputStream = DefaultOutputStream()

    private var isInitialized = false
    private let queue = DispatchQueue.global(qos: .userInteractive)

    public static func run(_ script: String) async throws {
        try await shared.run(script)
    }
    
    public static func execute(block: @escaping () throws -> Void) async throws {
        try await shared.execute(block: block)
    }
    
    @MainActor
    public static func output(to outputStream: OutputStream) {
        shared.outputStream = outputStream
    }
    
    public static func load(bundle: Bundle) async throws {
        bundle.load()
        
        guard let path = bundle.path(forResource: "PythonLibs", ofType: nil)else {
            throw InterpreterError.failedToLoadBundle
        }
        
        try await run("sys.path.append('\(path)')")
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
                    
                    DispatchQueue.main.sync {
                        Interpreter.shared.outputStream.finalize()
                    }
                    
                    continuation.resume()
                } catch {
                    DispatchQueue.main.sync {
                        Interpreter.shared.outputStream.finalize()
                    }

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
            DispatchQueue.main.async {
                Interpreter.shared.outputStream.receive(output: str)
            }
        }

        sys.stderr.write = .inject { (str: String) in
            DispatchQueue.main.async {
                Interpreter.shared.outputStream.receive(error: str)
            }
        }
        
        let major = sys.version_info.major
        let minor = sys.version_info.minor
        print("Initialized Python v\(major).\(minor)")

        isInitialized = true
    }
}
