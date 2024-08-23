//
//  Interpreter+loadBundle.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-08-23.
//

import Foundation
import PythonKit

 extension Interpreter {
     /// Should access in python thread only.
     static var loadedModules = Set<String>()
     
     /// Load a bundle if it isn't loaded already.
     ///
     /// Looks for resource path of `site-packages` and adds it to the Python path.
     /// - Parameters:
     ///   - bundle: bundle to load
     ///   - loaded: executed after the bundle is loaded on the python thread.
     public static func load(bundle: Bundle, loaded: (() throws -> Void)? = nil) async throws {
         try await perform {
             guard let identifier = bundle.bundleIdentifier,
                   !loadedModules.contains(identifier) else {
                 return
             }
             
             loadedModules.insert(identifier)
             
             bundle.load()
             
             guard let path = bundle.path(forResource: "site-packages", ofType: nil) else {
                 throw InterpreterError.failedToLoadBundle
             }
             
             
             let sys = Python.import("sys")
             sys.path.append(path)
             
             try loaded?()
             
             log.info("loaded \(identifier)")
         }
     }
}
