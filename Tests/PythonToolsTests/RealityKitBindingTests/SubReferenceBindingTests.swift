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
    @MainActor
    @Test func childrenExists() async throws {
        let entity = Entity()
        
        let binding = try await PythonBinding.make(entity)
        
        try await binding.withPythonObject { pythonEntity in
            let children = try? #require(pythonEntity.checking.children)
            #expect(children?.isEmpty == true)
        }
        
        let child = Entity()
        child.name = "child"
        entity.addChild(child)
        
        try await binding.withPythonObject { pythonObject in
            let pythonChildren = pythonObject.children
            #expect(Python.len(pythonChildren) == 1)
            let child = try? #require(pythonChildren[0])
            #expect(child?.name == "child")
        }
    }
    
    @MainActor
    @Test func valueBinding() async throws {
        let entity = Entity()
        
        let binding = try await PythonBinding.make(entity)
        
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
        
        let binding = try await PythonBinding.make(entity)
        
        try await binding.withPythonObject { pythonObject in
            pythonObject.transform.translation.x = 3
        }
        
        #expect(entity.transform.translation.x == 3)
    }
}
