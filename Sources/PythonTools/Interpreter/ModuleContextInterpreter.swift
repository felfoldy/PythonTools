//
//  ModuleContextInterpreter.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-25.
//

import PythonKit

public struct ModuleContextInterpreter: PythonInterpreter {
    let module: String
    let base: PythonInterpreter
    
    public func execute(block: @escaping () throws -> Void) async throws {
        try await base.execute(block: block)
    }
    
    public func execute(block: @escaping (PythonObject) throws -> Void) async throws {
        try await execute {
            let module = try Python.attemptImport(module)
            try block(module)
        }
    }
    
    func inject(member: String, object: @autoclosure @escaping () -> PythonObject) async throws {
        try await execute {
            let module = try Python.attemptImport(module)
            module[dynamicMember: member] = object()
        }
    }
    
    public func inject(_ name: String, function: @escaping () -> Void) async throws {
        try await inject(member: name, object: .inject(function))
    }
    
    public func inject<Input: ConvertibleFromPython>(_ name: String, function: @escaping (Input) -> Void) async throws {
        try await inject(member: name, object: .inject(function))
    }
}

public extension Interpreter {
    static func module(_ name: String) -> ModuleContextInterpreter {
        ModuleContextInterpreter(module: name, base: Interpreter.shared)
    }
}
