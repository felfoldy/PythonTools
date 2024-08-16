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
    
    init() {
        PythonCReferences.ensureReferences()
    }
    
    let defaultCompiler: Compiler = .evaluationCompiler
        .fallback(to: .fileCompiler)
        .outputError()

    public static func run(_ script: String, file: String = #file, line: Int = #line) async throws {
        let compilableCode = CompilableCode(source: script)
        let path = "<\(URL(string: file)!.lastPathComponent):\(line)>"
        trace(compilableCode.id, "\(path) run initied")
                
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
    
    @MainActor
    public static func load(bundle: Bundle) async throws {
        guard let identifier = bundle.bundleIdentifier,
              !shared.loadedModules.contains(identifier) else {
            return
        }
        
        shared.loadedModules.insert(identifier)

        bundle.load()
        
        guard let path = bundle.path(forResource: "site-packages", ofType: nil)else {
            throw InterpreterError.failedToLoadBundle
        }
        
        try await perform {
            let sys = Python.import("sys")
            sys.path.append(path)
        }
        
        log.info("load \(identifier)")
    }
    
    public static func completions(code: String) async throws -> [String] {
        try await load(bundle: .module)
        
        var compeltionsResult = [String]()
        try await shared.perform {
            let interpreter = try Python.attemptImport("interpreter")
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
                    DispatchQueue.main.sync {
                        Interpreter.shared.initializePythonEnvironment()
                    }
                }

                let interpreterState = PyInterpreterState_Head()
                let tState = PyThreadState_New(interpreterState)
                PyEval_RestoreThread(tState)

                defer {
                    PyEval_SaveThread()
                    PyThreadState_Clear(tState)
                    PyThreadState_Delete(tState)
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
    
    @MainActor
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
        
        let main = Python.import("__main__")
        
        main.clear = .inject {
            Interpreter.shared.outputStream.clear()
        }
        
        let major = sys.version_info.major
        let minor = sys.version_info.minor
        Interpreter.log.info("Initialized Python v\(major).\(minor)")

        isInitialized = true
        PyEval_SaveThread()
    }
}
