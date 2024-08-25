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
struct EntityBindingTests {
    init() throws {
        try Entity.register()
    }

    @Test
    func entityName() throws {
        let entity = Entity()
        entity.name = "name"
        
        try entity.withPythonObject { pythonEntity in
            #expect(pythonEntity.name == "name")
        }
    }

    @Test
    func entitySubclass() throws {
        let entity = ModelEntity()
        entity.name = "name"
        
        try entity.withPythonObject { pythonEntity in
            #expect(pythonEntity.name == "name")
        }
    }

    @Test
    func functionInjection() throws {
        let entity = Entity()
        entity.name = "name"
        
        try entity.withPythonObject { pythonEntity in
            #expect(pythonEntity.fetch_name() == "name")
        }
    }
}
