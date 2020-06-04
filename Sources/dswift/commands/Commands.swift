//
//  Commands.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-21.
//

import Foundation

/// Namespace where all the different commands are stored
public struct Commands {
    private init() { }
    
    private static func buildPrintLine(_ message: String,
                                       _ filename: String,
                                       _ line: Int,
                                       _ funcname: String) -> String {
        
        return "\(filename) - \(funcname)(\(line)): \(message)"
    }
    
    /// Print function for the dswift generator
    internal static func generatorPrint(_ message: String,
                                        _ filename: String,
                                        _ line: Int,
                                        _ funcname: String) {
        let msg = buildPrintLine(message, filename, line, funcname)
        print(msg)
    }
    /// Debug Print function for the dswift generator
    internal static func generatorDebugPrint(_ message: String,
                                             _ filename: String,
                                             _ line: Int,
                                             _ funcname: String) {
        let msg = buildPrintLine(message, filename, line, funcname)
        debugPrint(msg)
    }
    /// Verbose Print function for the dswift generator
    internal static func generatorVerbosePrint(_ message: String,
                                               _ filename: String,
                                               _ line: Int,
                                               _ funcname: String) {
        let msg = buildPrintLine(message, filename, line, funcname)
        verbosePrint(msg)
    }
}
