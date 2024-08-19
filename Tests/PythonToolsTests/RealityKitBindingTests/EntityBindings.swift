//
//  EntityBindings.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-08-14.
//

import RealityKit
import PythonTools
import PythonKit

class SIMD3Binding: PythonValueBindable<SIMD3<Float>> {
    static let pythonClassName = "SIMD3Float"
    
    static func register() async throws {
        try await PythonBinding.register(SIMD3Binding.self, members: [
            .set("x", \.value.x),
            .set("y", \.value.y),
            .set("z", \.value.z),
        ])
    }
}

class TransformComponent: PythonValueBindable<Transform> {
    static let pythonClassName = "Transform"
    
    static func register() async throws {
        try await SIMD3Binding.register()
        
        try await PythonBinding.register(TransformComponent.self, members: [
            .set("pos_x", \.value.translation.x),
            .value("translation", \.value.translation, as: SIMD3Binding.self)
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
        
        try await withPythonClass { object in
            object.fetch_name = .instanceFunction { (entity: Entity) in
                entity.name
            }
        }
    }
}
