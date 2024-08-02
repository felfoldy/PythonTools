//
//  PythonRuntimeMonitor.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-08-02.
//

import OSLog

private let pointOfInterest = OSLog(subsystem: "com.felfoldy.PythonTools", category: .pointsOfInterest)

public enum PythonRuntimeMonitor {
    public static let signposter = OSSignposter(logHandle: pointOfInterest)
    public static var currentSignpostID: OSSignpostID?
    public private(set) static var executionTime: UInt64 = 0
    
    static var state: OSSignpostIntervalState?
    
    private static var startTime: DispatchTime?
    
    static func start() {
        let signpostID = signposter.makeSignpostID()
        state = signposter.beginInterval("Python", id: signpostID)
        currentSignpostID = signpostID

        startTime = .now()
    }
    
    static func event(_ message: StaticString) {
        guard let currentSignpostID else { return }
        signposter.emitEvent(message, id: currentSignpostID)
    }
    
    static func end() {
        guard let state, let startTime else { return }
        signposter.endInterval("Python", state)

        let endTime = DispatchTime.now()
        
        executionTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
    }
}
