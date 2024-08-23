import Testing
import Foundation
import PythonKit
@testable import PythonTools

@Test func codeCompletion() async throws {
    let results = try await Interpreter.completions(code: "pri")
    
    #expect(results == ["print("])
}

@MainActor
@Test
func performOnMain() async throws {
    try await Interpreter.perform {
        let main = Python.import("__main__")
        print(main.checking.something == nil)
    }
    
    try Interpreter.performOnMain {
        let main = Python.import("__main__")
        main.something = "added"
    }
    
    try await Interpreter.perform {
        let main = Python.import("__main__")
        #expect(main.something == "added")
    }
}
