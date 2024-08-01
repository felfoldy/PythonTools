//
//  PythonBindingTests.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-07-30.
//

import Testing
import PythonKit
import PythonTools

class TestClass {
    let readOnlyValue: Int = 42
    var value: Int = 4
    var stringValue: String = ""
    var floatValue: Float = 3.2
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
            try await PythonBinding.register(
                TestClass.self,
                members: [
                    .int("value", \.value),
                    .int("read_only_value", \.readOnlyValue),
                    .string("string_value", \.stringValue),
                    .float("float_value", \.floatValue)
                ]
            )

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
            let pythonObject = try await binding.pythonObject()
            
            testObject.value = 42
            #expect(pythonObject.value == 42)
            
            pythonObject.value = 22
            #expect(testObject.value == 22)
        }
        
        @Test func stringRegistration() async throws {
            let pythonObject = try await binding.pythonObject()
            
            testObject.stringValue = "none"
            #expect(pythonObject.string_value == "none")
            
            pythonObject.string_value = "new value"
            #expect(testObject.stringValue == "new value")
        }
        
        @Test func floatRegistration() async throws {
            let pythonObject = try await binding.pythonObject()
            
            testObject.floatValue = 0.1
            #expect(Float(pythonObject.float_value) == 0.1)
        }
    }

    @Test func registerInModule() async throws {
        try await PythonBinding.register(
            TestClass.self, name: "TestClass", in: "builtins",
            members: [.int("value", \.value)]
        )

        let testObject = TestClass()
        let address = await PythonBinding(testObject).address
        
        try await Interpreter.perform {
            let builtins = Python.import("builtins")
            let pythonObject = builtins.TestClass(address)
            #expect(Int(pythonObject.value) == testObject.value)
        }
    }
}
