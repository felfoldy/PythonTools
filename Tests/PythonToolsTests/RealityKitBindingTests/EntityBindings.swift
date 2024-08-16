//
//  EntityBindings.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-08-14.
//

import RealityKit
import PythonTools
import PythonKit

class TransformComponent: PythonValueBindable<Transform>, PythonBindable {
    static let pythonClassName = "Transform"
    
    static func register() async throws {
        try await PythonBinding.register(TransformComponent.self, members: [
            .set("pos_x", \.value?.translation.x)
        ])
    }
}

extension Entity: @retroactive PythonBindable {
    public static var pythonClassName: String { "Entity" }
    
    public static func register() async throws {
        try await TransformComponent.register()
        try await PythonCollection<Entity, Entity.ChildCollection>.register()

        try await PythonBinding.register(
            Entity.self,
            members: [
                .set("name", \.name),
                .collection("children", \.children),
                .value("transform", \.transform, as: TransformComponent.self)
            ]
        )
        
        try await withClassPythonObject { object in
            object.fetch_name = .instanceFunction { (entity: Entity) in
                entity.name
            }
        }
    }
}
