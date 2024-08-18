//
//  EntityBindingTests.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-08-02.
//

import Testing
import RealityKit
import PythonTools
import PythonKit

@MainActor
@Test
func entityName() async throws {
    let entity = Entity()
    entity.name = "name"
    
    try await PythonBinding.make(entity).withPythonObject { pythonEntity in
        #expect(pythonEntity.name == "name")
    }
}

@MainActor
@Test
func entitySubclass() async throws {
    let entity = ModelEntity()
    entity.name = "name"
    
    try await PythonBinding.make(entity).withPythonObject { pythonEntity in
        #expect(pythonEntity.name == "name")
    }
}

@MainActor
@Test func functionInjection() async throws {
    let entity = Entity()
    entity.name = "name"
    
    try await Entity.register()
    
    try await PythonBinding.make(entity).withPythonObject { pythonEntity in
        #expect(pythonEntity.fetch_name() == "name")
    }
}
