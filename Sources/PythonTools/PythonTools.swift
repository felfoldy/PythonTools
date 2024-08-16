// The Swift Programming Language
// https://docs.swift.org/swift-book

import OSLog

extension Interpreter {
    static let log = Logger(subsystem: "com.felfoldy.PythonTools", category: "Interpreter")
    
    static func trace(_ id: UUID, _ message: String) {
        log.trace("\(id.uuidString.prefix(8)) - \(message)")
    }
}
