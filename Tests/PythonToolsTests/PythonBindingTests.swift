//
//  PythonBindingTests.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-07-30.
//

import Testing
import PythonKit
@testable import PythonTools

class InnerTestClass {
    var value = "hidden"
}

class TestClass {
    var value: Int = 4
    var stringValue: String = ""
    var floatValue: Float = 3.2
    var optionalValue: Int? = 12
    
    var innerObject = InnerTestClass()
    var optionalObject: InnerTestClass? = InnerTestClass()
}

extension InnerTestClass: PythonBindable {
    static var pythonClassName: String {
        "InnerTestClass"
    }
    
    static func register() async throws {
        try await PythonBinding.register(
            InnerTestClass.self,
            members: [.set("value", \.value)]
        )
    }
}

extension TestClass: PythonBindable {
    static var pythonClassName: String {
        "TestClass"
    }
    
    static func register() async throws {
        try await PythonBinding.register(
            TestClass.self,
            members: [
                .set("value", \.value),
                .set("string_value", \.stringValue),
                .set("float_value", \.floatValue),
                .set("optional_value", \.optionalValue),
                .set("inner_object", \.innerObject),
                .set("optional_object", \.optionalObject),
            ]
        )
    }
}

enum TestNS { class TestClass {} }

struct PythonBindingTests {
    @Test
    @MainActor
    func init_shouldRegisterBinding() async throws {
        let test = TestClass()
        let address = test.address
        
        try await test.binding()

        try #require(address != 0)

        try await test.withPythonObject { pythonObject in
            let testClass = TestClass.from(pythonObject)
            
            #expect(testClass === test)
        }
    }
    
    @Suite(.serialized)
    struct RegisterBinding {
        let testObject: TestClass
        
        init() async throws {
            try await TestClass.register()
            testObject = TestClass()
        }
        
        @Test func register() async throws {
            let testAddress = testObject.address
            
            try await Interpreter.run(
                "test = TestClass(\(testAddress))"
            )
            
            try await Interpreter.perform {
                let main = Python.import("__main__")
                let address = main.test._address
                
                #expect(testAddress == Int(address))
            }
        }
        
        @MainActor
        @Test
        func intRegistration() throws {
            testObject.value = 42
            
            try testObject.withPythonObject { pythonObject in
                #expect(pythonObject.value == 42)
                
                pythonObject.value = 22
                #expect(testObject.value == 22)
            }
        }
        
        @MainActor
        @Test func stringRegistration() throws {
            try testObject.withPythonObject { pythonObject in
                testObject.stringValue = "none"
                #expect(pythonObject.string_value == "none")
                
                pythonObject.string_value = "new value"
                #expect(testObject.stringValue == "new value")
            }
        }
        
        @Test func floatRegistration() async throws {
            testObject.floatValue = 0.1
            
            try await testObject.withPythonObject { pythonObject in
                #expect(Float(pythonObject.float_value) == 0.1)
            }
        }
        
        @Test func optionalRegistration() async throws {
            try await testObject.withPythonObject { pythonObject in
                testObject.optionalValue = 32
                
                #expect(pythonObject.optional_value == 32)
                    
                pythonObject.optional_value = Python.None
                
                #expect(testObject.optionalValue == nil)
            }
        }
        
        @Test
        @MainActor
        func weakBinding() async throws {
            var test: TestClass? = TestClass()
            let binding = try await test!.binding()

            try await binding.withPythonObject { pythonObject in
                #expect(pythonObject != Python.None)
            }
            
            test = nil
            
            try await binding.withPythonObject { pythonObject in
                #expect(pythonObject.checking.name == nil)
            }
        }
    }
    
    @Test func reference() async throws {
        try await InnerTestClass.register()
        try await TestClass.register()
        
        let testObject = TestClass()
        
        try await testObject.withPythonObject { pythonObject in
            #expect(pythonObject.inner_object.value == "hidden")
        }
        
        let newInnerObject = InnerTestClass()
        newInnerObject.value = "revealed"
        
        try await testObject.withPythonObject { pythonObject in
            pythonObject.inner_object = newInnerObject.pythonObject
            
            #expect(pythonObject.inner_object.value == "revealed")
        }
    }
    
    @Test
    func optionalReference() async throws {
        try await InnerTestClass.register()
        try await TestClass.register()
        
        let testObject = TestClass()
        
        try await testObject.withPythonObject { pythonObject in
            #expect(pythonObject.optional_object.value == "hidden")
            
            testObject.optionalObject = nil
            #expect(pythonObject.optional_object == Python.None)
        }
    }
}
