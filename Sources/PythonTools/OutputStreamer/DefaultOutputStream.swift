//
//  DefaultOutputStreamer.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-26.
//

final class DefaultOutputStream: OutputStream {
    var outputBuffer = [String]()
    var errorBuffer = [String]()
    
    func finalize() {
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
}

