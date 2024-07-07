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

public final class Interpreter {
    static let shared = Interpreter()
    
    @MainActor
    public var outputStream: OutputStream = DefaultOutputStream()

    private var isInitialized = false
    
    @MainActor
    private var loadedModules = Set<String>()
    private let queue = DispatchQueue(label: "PythonQueue",
                                      qos: .userInteractive)
    private let queueKey = DispatchSpecificKey<Void>()
    
    init() {
        queue.setSpecific(key: queueKey, value: ())
    }
    
    let defaultCompiler: Compiler = .evaluationCompiler
        .fallback(to: .fileCompiler)
        .outputError()

    public static func run(_ script: String) async throws {
        let compilableCode = CompilableCode(source: script)

        let compiledCode = try await Interpreter.compile(code: compilableCode)

        try await Interpreter.execute(compiledCode: compiledCode)
    }
    
    public static func perform(block: @escaping () throws -> Void) async throws {
        try await shared.perform(block: block)
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
        
        try await perform {
            let sys = Python.import("sys")
            sys.path.append(path)
        }
        
        await MainActor.run {
            _ = shared.loadedModules.insert(identifier)
        }
    }
    
    public static func completions(code: String) async throws -> [String] {
        try await load(bundle: .module)
        
        var compeltionsResult = [String]()
        try await shared.perform {
            let interpreter = Python.import("interpreter")
            let results = interpreter._completions(code)
                .compactMap(String.init)

            compeltionsResult = results
        }
        return compeltionsResult
    }
}

extension Interpreter {
    public func perform(block: @escaping () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if !Interpreter.shared.isInitialized {
                    Interpreter.shared.initializePythonEnvironment()
                }

                do {
                    try block()
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func syncQueue(block: () -> Void) {
        if queue.getSpecific(key: queueKey) != nil {
            block()
        } else {
            queue.sync {
                block()
            }
        }
    }
    
    private func initializePythonEnvironment() {
        PyBundler.shared.pyInit()
        let sys = Python.import("sys")

        // Inject output stream
        sys.stdout.write = .inject { (str: String) in
            Task { @MainActor in
                Interpreter.shared.outputStream.receive(output: str)
            }
        }

        sys.stderr.write = .inject { (str: String) in
            Task { @MainActor in
                Interpreter.shared.outputStream.receive(error: str)
            }
        }
        
        let main = Python.import("__main__")
        
        main.clear = .inject {
            Task { @MainActor in
                Interpreter.shared.outputStream.clear()
            }
        }
        
        let major = sys.version_info.major
        let minor = sys.version_info.minor
        Interpreter.log.info("Initialized Python v\(major).\(minor)")

        isInitialized = true
    }
}
