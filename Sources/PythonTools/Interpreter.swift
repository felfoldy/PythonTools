//
//  Interpreter.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-25.
//

import Foundation
import PyBundle
import Python
import PythonKit

public final class Interpreter {
    private static let shared = Interpreter()
    private static var isInitialized = false

    private let queue = DispatchQueue.global(qos: .userInteractive)
    
    public static func setup() async throws {
        try await shared.execute {
            // TODO: Setup console output
            let sys = Python.import("sys")
            
            // (str) -> None
            sys.stdout.write = PythonFunction { params in
                print(String(params[0])!, terminator: "")
                return Python.None
            }
            .pythonObject
            
            // (str) -> None
            sys.stderr.write = PythonFunction { params in
                print(String(params[0])!, terminator: "")
                return Python.None
            }
            .pythonObject
        }
    }

    public func run(_ script: String) async throws {
        try await execute {
            let result = PyRun_SimpleString(script)
            
            if result != 0 {
                throw Error.nonZero(result)
            }
        }
    }
    
    public static func run(_ script: String) async throws {
        try await shared.run(script)
    }
    
    public static func execute(block: @escaping () throws -> Void) async throws {
        try await shared.execute(block: block)
    }
}

private extension Interpreter {
    func execute(block: @escaping () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if !Interpreter.isInitialized {
                    _ = PyBundler.shared
                    let sys = Python.import("sys")
                    print("Initialized Python v\(sys.version_info.major).\(sys.version_info.minor)")
                    Interpreter.isInitialized = true
                }
                
                // TODO: Add OSSignpost logging.
                do {
                    try block()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

public extension Interpreter {
    enum Error: LocalizedError {
        case nonZero(Int32)
        
        public var errorDescription: String? {
            switch self {
            case let .nonZero(code):
                "Python script terminated with non-zero exit code: \(code)"
            }
        }
    }
}
