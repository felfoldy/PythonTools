//
//  PythonRuntimeMonitor.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-08-02.
//

import OSLog

private let pointOfInterest = OSLog(subsystem: "com.felfoldy.PythonTools", category: .pointsOfInterest)


// TODO: A better monitoring system would be nice.

public enum PythonRuntimeMonitor {
    public static let signposter = OSSignposter(logHandle: pointOfInterest)

    nonisolated(unsafe) public static var currentSignpostID: OSSignpostID?
    nonisolated(unsafe) public private(set) static var executionTime: UInt64 = 0
    
    nonisolated(unsafe) static var state: OSSignpostIntervalState?
    
    nonisolated(unsafe) private static var startTime: DispatchTime?
    
    public static func start() {
        let signpostID = signposter.makeSignpostID()
        state = signposter.beginInterval("Python", id: signpostID)
        currentSignpostID = signpostID

        startTime = .now()
    }
    
    static func event(_ message: StaticString) {
        guard let currentSignpostID else { return }
        signposter.emitEvent(message, id: currentSignpostID)
    }
    
    public static func end() {
        guard let state, let startTime else { return }
        signposter.endInterval("Python", state)

        let endTime = DispatchTime.now()
        
        executionTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        
        currentSignpostID = nil
    }
}
