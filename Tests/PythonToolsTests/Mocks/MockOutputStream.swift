//
//  MockOutputStream.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-27.
//

import PythonTools
import Foundation

@MainActor
class MockOutputStream: PythonTools.OutputStream {
    var outputBuffer: [String] = []
    var errorBuffer: [String] = []
    
    var finalizeCallCount = 0
    var lastExecutionTime: UInt64?
    var lastCodeId: UUID?
    func finalize(codeId: UUID, executionTime: UInt64) {
        lastCodeId = codeId
        finalizeCallCount += 1
        lastExecutionTime = executionTime
    }

    var lastEvaluationResult: String?
    func evaluation(result: String) {
        lastEvaluationResult = result
    }
    
    var clearCallCount = 0
    func clear() {
        clearCallCount += 1
    }
}
