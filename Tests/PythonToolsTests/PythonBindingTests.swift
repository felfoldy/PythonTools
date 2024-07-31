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
    var value: Int = 4
}

enum TestNS {
    class TestClass {}
}

struct PythonBindingTests {
    @Test func className() {
        #expect(PythonBinding.className(TestClass()) == "PythonToolsTests_TestClass")
        #expect(PythonBinding.className(TestClass.self) == "PythonToolsTests_TestClass")
        #expect(PythonBinding.className(TestNS.TestClass.self) == "PythonToolsTests_TestNS_TestClass")
    }
    
    @Test func address() throws {
        let test = TestClass()
        
        let address = PythonBinding(test).address

        try #require(address != 0)

        let result: TestClass = try PythonBinding.from(address: address)
        
        #expect(result.value == 4)
        
        test.value = 8
        
        #expect(result.value == 8)
    }
    
    @Test func weakBinding() throws {
        var test: TestClass? = TestClass()
        let address = PythonBinding(test!).address
        
        let _: TestClass = try #require(try? PythonBinding.from(address: address))
        
        test = nil
        
        #expect(throws: PythonBindingError.self) {
            let _: TestClass = try PythonBinding.from(address: address)
        }
    }
    
    @Test func register() async throws {
        try await PythonBinding.register(TestClass.self)
        
        let test = TestClass()
        
        let testAddress = PythonBinding(test).address
        
        try await Interpreter.run(
            "test = PythonToolsTests_TestClass(\(testAddress))"
        )
        
        try await Interpreter.perform {
            let main = Python.import("__main__")
            let address = main.test._address
            
            #expect(testAddress == Int(address))
        }
    }
}
