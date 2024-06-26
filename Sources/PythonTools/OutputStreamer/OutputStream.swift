//
//  PythonOutputStreamer.swift
//  
//
//  Created by Tibor Felföldy on 2024-06-26.
//

public protocol OutputStream: AnyObject {
    var outputBuffer: [String] { get set }
    var errorBuffer: [String] { get set }
    
    func finalize()
}

extension OutputStream {
    func receive(output: String) {
        outputBuffer.append(output)
        print(output, terminator: "")
    }
    
    func receive(error: String) {
        errorBuffer.append(error)
        print(error, terminator: "")
    }
    
    var errorMessage: String {
        errorBuffer
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
