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
                    .int("read_only_value", \.readOnlyValue)
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
        
        @Test func pythonObject() async throws {
            let address = await binding.address

            let pythonObject = try await binding.pythonObject()

            try await Interpreter.perform {
                #expect(Int(pythonObject._address) == address)
            }
        }
        
        @Test func intRegistration() async throws {
            try await PythonBinding.register(
                TestClass.self,
                members: [.int("value", \.value)]
            )
            
            let binding = PythonBinding(testObject)
            
            let pythonObject = try await binding.pythonObject()
            
            testObject.value = 42
            #expect(pythonObject.value == 42)
            
            pythonObject.value = 22
            #expect(testObject.value == 22)
        }
    }
}
