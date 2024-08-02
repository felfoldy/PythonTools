//
//  PythonBindingTests.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-07-30.
//

import Testing
import PythonKit
import PythonTools

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
    static func register() async throws {
        try await PythonBinding.register(
            InnerTestClass.self,
            members: [.set(\.value)]
        )
    }
}

extension TestClass: PythonBindable {
    static func register() async throws {
        try await PythonBinding.register(
            TestClass.self,
            members: [
                .set(\.value),
                .set(\.stringValue),
                .set(\.floatValue),
                .set(\.optionalValue),
                .set(\.innerObject),
                .set(\.optionalObject),
            ]
        )
    }
}

enum TestNS { class TestClass {} }

struct PythonBindingTests {
    @Test
    func className() {
        #expect(PythonBinding.className(TestClass()) == "PythonToolsTests_TestClass")
        #expect(PythonBinding.className(TestClass.self) == "PythonToolsTests_TestClass")
        #expect(PythonBinding.className(TestNS.TestClass.self) == "PythonToolsTests_TestNS_TestClass")
    }

    @Test
    @MainActor
    func address() throws {
        let test = TestClass()
        
        let address = PythonBinding(test).address

        try #require(address != 0)

        let result: TestClass = try PythonBinding.from(address: address)
        
        #expect(result.value == 4)
        
        test.value = 8
        
        #expect(result.value == 8)
    }
    
    @Test
    @MainActor
    func weakBinding() throws {
        var test: TestClass? = TestClass()
        let address = PythonBinding(test!).address
        
        let _: TestClass = try #require(try? PythonBinding.from(address: address))
        
        test = nil
        
        #expect(throws: PythonBindingError.self) {
            let _: TestClass = try PythonBinding.from(address: address)
        }
    }
    
    struct RegisterBinding {
        let testObject: TestClass
        let binding: PythonBinding
        
        init() async throws {
            try await TestClass.register()
            testObject = TestClass()
            binding = PythonBinding(testObject)
        }
        
        @Test func register() async throws {
            let testAddress = await binding.address
            
            try await Interpreter.run(
                "test = PythonToolsTests_TestClass(\(testAddress))"
            )
            
            try await Interpreter.perform {
                let main = Python.import("__main__")
                let address = main.test._address
                
                #expect(testAddress == Int(address))
            }
        }
        
        @Test func intRegistration() async throws {
            try await Interpreter.perform {
                let pythonObject = binding.pythonObject
                
                testObject.value = 42
                #expect(pythonObject.value == 42)
                
                pythonObject.value = 22
                #expect(testObject.value == 22)
            }
        }
        
        @Test func stringRegistration() async throws {
            try await Interpreter.perform {
                let pythonObject = binding.pythonObject
                
                testObject.stringValue = "none"
                #expect(pythonObject.string_value == "none")
                
                pythonObject.string_value = "new value"
                #expect(testObject.stringValue == "new value")
            }
        }
        
        @Test func floatRegistration() async throws {
            try await Interpreter.perform {
                let pythonObject = binding.pythonObject
                
                testObject.floatValue = 0.1
                #expect(Float(pythonObject.float_value) == 0.1)
            }
        }
        
        @Test func optionalRegistration() async throws {
            try await Interpreter.perform {
                let pythonObject = binding.pythonObject
                
                testObject.optionalValue = 32
                
                #expect(pythonObject.optional_value == 32)
                    
                pythonObject.optional_value = Python.None
                
                #expect(testObject.optionalValue == nil)
            }
        }
    }

    @Test func registerInModule() async throws {
        try await PythonBinding.register(
            TestClass.self, name: "TestClass", in: "builtins",
            members: [.set("value", \.value)]
        )

        let testObject = TestClass()
        let address = await PythonBinding(testObject).address
        
        try await Interpreter.perform {
            let builtins = Python.import("builtins")
            let pythonObject = builtins.TestClass(address)
            #expect(Int(pythonObject.value) == testObject.value)
        }
    }
    
    @Test func reference() async throws {
        try await InnerTestClass.register()
        try await TestClass.register()
        
        let testObject = TestClass()
        
        try await Interpreter.perform {
            let pythonObject = testObject.pythonObject
            
            #expect(pythonObject.inner_object.value == "hidden")
        }
        
        let newInnerObject = InnerTestClass()
        newInnerObject.value = "revealed"
        
        try await Interpreter.perform {
            let pythonObject = testObject.pythonObject
            
            pythonObject.inner_object = newInnerObject.pythonObject
            
            #expect(pythonObject.inner_object.value == "revealed")
        }
    }
    
    @Test
    func optionalReference() async throws {
        try await InnerTestClass.register()
        try await TestClass.register()
        
        let testObject = TestClass()
        
        try await Interpreter.perform {
            let pythonObject = testObject.pythonObject
            
            #expect(pythonObject.optional_object.value == "hidden")
            
            testObject.optionalObject = nil
            #expect(pythonObject.optional_object == Python.None)
        }
    }
}
