//
//  DefaultOutputStreamer.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-26.
//

import Foundation

final class DefaultOutputStream: OutputStream {
    var outputBuffer = [String]()
    var errorBuffer = [String]()
    
    func finalize(codeId: UUID, executionTime: UInt64) {
        let out = outputBuffer.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !out.isEmpty {
            print("out: \(out)")
        }
        
        let err = errorBuffer.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !err.isEmpty {
            print("err: \(err)")
        }
        
        outputBuffer = []
        errorBuffer = []
    }

    func evaluation(result: String) {
        print("Result: \(result)")
    }
    
    func clear() {}
}

