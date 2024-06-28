//
//  MockOutputStream.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-27.
//

import PythonTools

class MockOutputStream: OutputStream {
    var outputBuffer: [String] = []
    var errorBuffer: [String] = []
    
    var output: String {
        outputBuffer.joined()
    }
    
    var finalizeCallCount = 0
    func finalize() {
        finalizeCallCount += 1
    }
    

    var lastEvaluationResult: String?
    func evaluation(result: String) {
        lastEvaluationResult = result
    }
}
