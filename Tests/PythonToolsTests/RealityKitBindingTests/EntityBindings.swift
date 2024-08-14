//
//  EntityBindings.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-08-14.
//

import RealityKit
import PythonTools
import PythonKit

extension Entity: @retroactive PythonBindable {
    public static var pythonClassName: String { "Entity" }
    
    public static func register() async throws {
        try await PythonCollection<Entity, Entity.ChildCollection>.register()

        try await PythonBinding.register(
            Entity.self,
            members: [
                .set("name", \.name),
                .collection("children", \.children)
            ]
        )
        
        try await withClassPythonObject { object in
            object.fetch_name = .instanceFunction { (entity: Entity) in
                entity.name
            }
        }
    }
}
