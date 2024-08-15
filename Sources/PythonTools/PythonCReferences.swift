//
//  PythonCReferences.swift
//  PythonTools
//
//  Created by Tibor Felföldy on 2024-08-02.
//

import Python

enum PythonCReferences {
    public static var references: [Any] = [
        PyRun_SimpleString,
        PyCFunction_NewEx,
        PyTuple_SetItem,
        PyInstanceMethod_New,
    ]
    
    public static func ensureReferences() {
        if references.isEmpty {
            print("Something went wrong")
        }
    }
}
