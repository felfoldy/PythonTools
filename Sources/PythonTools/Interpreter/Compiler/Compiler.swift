//
//  Compiler.swift
//  
//
//  Created by Tibor Felföldy on 2024-07-05.
//

import Python
import Foundation

public struct CompilableCode: Identifiable {
    /// Identity to keep track the code for time profiling.
    public let id = UUID()
    
    /// The code to compile.
    let source: String
    
    /// Filename or source of the code. For interpreter the default is `<stdin>`.
    let filename: String
    
    public init(source: String, filename: String = "<stdin>") {
        self.source = source
        self.filename = filename
    }
}

public final class CompiledByteCode: Identifiable {
    public let id: UUID
    let byteCode: UnsafeMutablePointer<PyObject>

    init(id: UUID, byteCode: UnsafeMutablePointer<PyObject>) {
        self.id = id
        self.byteCode = byteCode
    }
    
    deinit {
        Interpreter.trace(id, "bytecode deinit")
        Task { [byteCode] in
            try? await Interpreter.perform {
                Py_DecRef(byteCode)
            }
        }
    }
}

public protocol Compiler {
    func compile(code: CompilableCode) async throws -> CompiledByteCode
}

extension Compiler {
    func compile(_ code: String) async throws -> CompiledByteCode {
        try await compile(code: CompilableCode(source: code))
    }
}

extension Interpreter {
    static func compile(code: CompilableCode, using compiler: Compiler? = nil) async throws -> CompiledByteCode {
        try await (compiler ?? shared.defaultCompiler)
            .compile(code: code)
    }
}
