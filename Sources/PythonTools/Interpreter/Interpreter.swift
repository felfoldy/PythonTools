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
    
    @MainActor
    private var loadedModules = Set<String>()
    private let queue = DispatchQueue(label: "PythonQueue",
                                      qos: .userInteractive)

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
        guard let identifier = bundle.bundleIdentifier,
              await !shared.loadedModules.contains(identifier) else {
            return
        }

        log.info("load \(identifier)")

        bundle.load()
        
        guard let path = bundle.path(forResource: "site-packages", ofType: nil)else {
            throw InterpreterError.failedToLoadBundle
        }
        
        try await run("sys.path.append('\(path)')")
        
        await MainActor.run {
            _ = shared.loadedModules.insert(identifier)
        }
    }
    
    public static func completions(code: String) async throws -> [String] {
        try await load(bundle: .module)
        
        var compeltionsResult = [String]()
        try await shared.execute {
            let code_completions = Python.import("interpreter")
            let results = code_completions.completions(code)
                .compactMap(String.init)
            compeltionsResult = results
        }
        return compeltionsResult
    }
}

extension Interpreter {
    public func execute(block: @escaping () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if !Interpreter.shared.isInitialized {
                    Interpreter.shared.initializePythonEnvironment()
                }

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
        Interpreter.log.info("Initialized Python v\(major).\(minor)")

        isInitialized = true
    }
}
