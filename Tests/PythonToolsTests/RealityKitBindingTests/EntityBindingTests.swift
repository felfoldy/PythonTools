//
//  EntityBindingTests.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-08-02.
//

import Testing
import RealityKit
import PythonTools

extension Entity: @retroactive PythonBindable {
    public static var pythonClassName: String { "Entity" }
    
    public static func register() async throws {
        try await PythonBinding.register(
            Entity.self,
            members: [.set("name", \.name)]
        )
    }
}

@Test func entityName() async throws {
    let entity = await Entity()
    await MainActor.run {
        entity.name = "name"
    }
    
    try await Entity.register()
    
    try await Interpreter.perform {
        let pythonEntity = entity.pythonObject
        
        #expect(pythonEntity.name == "name")
    }
}

@Test func entitySubclass() async throws {
    let entity = await ModelEntity()
    await MainActor.run {
        entity.name = "name"
    }
    
    try await Entity.register()
    
    try await Interpreter.perform {
        let pythonEntity = entity.pythonObject
        
        #expect(pythonEntity.name == "name")
    }
}
