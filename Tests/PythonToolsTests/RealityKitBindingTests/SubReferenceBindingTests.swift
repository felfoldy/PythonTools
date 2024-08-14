//
//  SubReferenceBindingTests.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-08-14.
//

import Testing
import RealityKit
import PythonTools
import PythonKit

struct EntityChildCollectionTests {
    @Test func childrenExists() async throws {
        try await Entity.register()
        
        let entity = await Entity()
        
        try await Interpreter.perform {
            let pythonEntity = entity.pythonObject

            let children = try #require(pythonEntity.checking.children)

            #expect(children.isEmpty)
        }
        
        await MainActor.run { [entity] in
            let child = Entity()
            child.name = "child"
            entity.addChild(child)
        }

        try await Interpreter.perform {
            let pythonChildren = entity.pythonObject.children

            #expect(Python.len(pythonChildren) == 1)
            let child = try #require(pythonChildren[0])
            #expect(child.name == "child")
        }
    }
}
