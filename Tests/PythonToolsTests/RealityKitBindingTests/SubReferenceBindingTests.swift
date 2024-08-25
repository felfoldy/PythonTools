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

@Suite(.serialized)
struct EntityChildCollectionTests {
    init() async throws {
        try await Entity.register()
    }
    
    @MainActor
    @Test func childrenExists() throws {
        let entity = Entity()
        
        try entity.withPythonObject { pythonEntity in
            let children = pythonEntity.children
            print(children)
            #expect(children.isEmpty == true)
        }
        
        let child = Entity()
        child.name = "child"
        entity.addChild(child)
        
        try entity.withPythonObject { pythonObject in
            let pythonChildren = pythonObject.children
            #expect(Python.len(pythonChildren) == 1)
            let child = try? #require(pythonChildren[0])
            #expect(child?.name == "child")
        }
    }
    
    @MainActor
    @Test func valueBinding() async throws {
        let entity = Entity()
        
        let binding = try entity.binding()
        
        try await binding.withPythonObject { pythonObject in
            #expect(pythonObject.transform.pos_x == 0)
        }

        entity.transform.translation.x = 3
        
        try await binding.withPythonObject { pythonObject in
            #expect(pythonObject.transform.pos_x == 3)
        }
    }
    
    @MainActor
    @Test("Value bindable setter")
    func registerSetter() async throws {
        let entity = Entity()
        
        let binding = try entity.binding()
        
        try await binding.withPythonObject { pythonObject in
            pythonObject.transform.translation.x = 3
        }
        
        #expect(entity.transform.translation.x == 3)
    }
}
