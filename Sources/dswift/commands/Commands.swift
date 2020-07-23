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
    /// Finds the path to the given command or returns nil if the command is not found
    internal static func which(_ command: String) -> String? {
        #if os(Windows)
        let dirSeperator: String = "\\"
        let pathSeperator: Character = ";"
        #else
        let dirSeperator: String = "/"
        let pathSeperator: Character = ":"
        #endif
        
        let pathsStr = ProcessInfo.processInfo.environment["PATH"] ?? ""
        
        let paths = pathsStr.split(separator: pathSeperator).map(String.init)
        for var path in paths {
            // If we have a marker for the current directory lets change to full path
            if path == "." || path == ".\(dirSeperator)" { path = FileManager.default.currentDirectoryPath }
            // Make sure path exists
            guard FileManager.default.fileExists(atPath: path) else { continue}
            
            // Build url to the command within the path
            let cmdURL = URL(fileURLWithPath: path, isDirectory: true).appendingPathComponent(command, isDirectory: false)
            
            // Make sure the full command path exists
            guard FileManager.default.fileExists(atPath: cmdURL.path) else { continue }
            // Make sure that the command is executable
            guard FileManager.default.isExecutableFile(atPath: cmdURL.path) else { continue }
            
            return cmdURL.path
            
        }
        return nil
    }
    
}
