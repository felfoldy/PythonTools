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
    @MainActor
    static let shared = Interpreter()

    @MainActor
    public var outputStream: OutputStream = DefaultOutputStream()

    @MainActor
    private var isInitialized = false

    private let queue = DispatchQueue(label: "PythonQueue",
                                      qos: .userInteractive)
    
    @MainActor
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

        let compiledCode = try await shared.defaultCompiler.compile(code: compilableCode)

        try await Interpreter.execute(compiledCode: compiledCode)
    }
    
    @MainActor
    public static func output(to outputStream: OutputStream) {
        shared.outputStream = outputStream
    }
    
    public static func completions(code: String) async throws -> [String] {        
        var compeltionsResult = [String]()
        try await perform {
            let interpreter = try Python.attemptImport("interpreter")
            let results = interpreter._completions(code)
                .compactMap(String.init)

            compeltionsResult = results
        }
        return compeltionsResult
    }
}

extension Interpreter {
    @MainActor
    public static func performOnMain(block: @MainActor () throws -> Void) throws {
        if !shared.isInitialized {
            shared.isInitialized = true
            try shared.initializePythonEnvironment()
        }
        
        try setThreadState {
            try block()
        }
    }
    
    public static func perform(block: @escaping () throws -> Void) async throws {
        try await MainActor.run {
            if !shared.isInitialized {
                shared.isInitialized = true
                try shared.initializePythonEnvironment()
            }
        }
        
        let queue = await shared.queue
        
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try Interpreter.setThreadState {
                        try block()
                    }

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func setThreadState(block: () throws -> Void) throws {
        let interpreterState = PyInterpreterState_Head()
        let tState = PyThreadState_New(interpreterState)
        PyEval_RestoreThread(tState)
        
        defer {
            PyEval_SaveThread()
            PyThreadState_Clear(tState)
            PyThreadState_Delete(tState)
        }
        
        try block()
    }
    
    @MainActor
    private func initializePythonEnvironment() throws {
        PyBundler.shared.pyInit()
        let sys = Python.import("sys")
        
        if let identifier = Bundle.module.bundleIdentifier {
            Interpreter.loadedModules.insert(identifier)
            
            guard let path = Bundle.module.path(forResource: "site-packages", ofType: nil) else {
                throw InterpreterError.failedToLoadBundle
            }
            
            sys.path.append(path)
        }

        // Inject output stream
        sys.stdout.write = .inject { (str: String) in
            Interpreter.shared.outputStream.receive(output: str)
        }

        sys.stderr.write = .inject { (str: String) in
            Interpreter.shared.outputStream.receive(error: str)
        }
        
        let main = Python.import("__main__")
        
        main._clear = .inject {
            Interpreter.shared.outputStream.clear()
        }
        
        PyRun_SimpleString("""
        def clear():
            _clear()
        """)
        
        let major = sys.version_info.major
        let minor = sys.version_info.minor
        Interpreter.log.info("Initialized Python v\(major).\(minor)")

        PyEval_SaveThread()
    }
}
