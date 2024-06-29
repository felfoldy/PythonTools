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
    
    var lastExecutionTime: UInt64?
    func execution(time: UInt64) {
        lastExecutionTime = time
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
