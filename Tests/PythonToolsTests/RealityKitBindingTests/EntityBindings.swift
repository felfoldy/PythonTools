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
    
    static func register() throws {
        try PythonBinding.register(SIMD3Binding.self, members: [
            .set("x", \.x),
            .set("y", \.y),
            .set("z", \.z),
        ])
    }
}

class TransformComponent: PythonValueBindable<Transform> {
    static let pythonClassName = "Transform"
    
    static func register() throws {
        try SIMD3Binding.register()
        
        try PythonBinding.register(TransformComponent.self, members: [
            .set("pos_x", \.translation.x),
            .value("translation", \.translation, as: SIMD3Binding.self)
        ])
    }
}

extension Entity: @retroactive PythonConvertible {}
extension Entity: PythonBindable {
    public static var pythonClassName: String { "Entity" }
    
    @MainActor
    public static func register() throws {
        try TransformComponent.register()
        try PythonCollection<Entity, Entity.ChildCollection>.register()

        try PythonBinding.register(
            Entity.self,
            members: [
                .set("name", \.name),
                .collection("children", \.children),
                .value("transform", \.transform, as: TransformComponent.self)
            ]
        )
        
        try withPythonClass { object in
            object.fetch_name = .instanceFunction { (entity: Entity) in
                entity.name
            }
        }
    }
}
