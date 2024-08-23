//
//  MockOutputStream.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-27.
//

import PythonTools
import Foundation

class MockOutputStream: PythonTools.OutputStream {    
    var outputBuffer: [String] = []
    var errorBuffer: [String] = []
    
    var finalizeCallCount = 0
    var lastExecutionTime: UInt64?
    var finalizedCodes = Set<UUID>()
    func finalize(codeId: UUID, executionTime: UInt64) {
        finalizedCodes.insert(codeId)
        finalizeCallCount += 1
        lastExecutionTime = executionTime
    }

    var evaluationResults = Set<String>()
    func evaluation(result: String) {
        evaluationResults.insert(result)
    }
    
    var clearCallCount = 0
    func clear() {
        clearCallCount += 1
    }
}
