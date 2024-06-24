//
//  Interpreter.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-25.
//

import Foundation
import PyBundle
import Python

public final class Interpreter {
    let queue = DispatchQueue.global(qos: .userInteractive)
    
    init() async {
        await withCheckedContinuation { continuation in
            queue.async {
                PyBundler.shared.pyInfo()
                continuation.resume()
            }
        }
    }
    
    func run(script: String) async throws {
        try await execute {
            let result = PyRun_SimpleString(script)
            
            if result != 0 {
                throw Error.nonZero(result)
            }
        }
    }
    
    private func execute(block: @escaping () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
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
