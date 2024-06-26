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
    private static var isInitialized = false

    private let queue = DispatchQueue.global(qos: .userInteractive)
    
    public static func run(_ script: String) async throws {
        try await shared.run(script)
    }
    
    public static func execute(block: @escaping () throws -> Void) async throws {
        try await shared.execute(block: block)
    }
}

extension Interpreter {
    public func execute(block: @escaping () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if !Interpreter.isInitialized {
                    PyBundler.shared.pyInfo()
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
