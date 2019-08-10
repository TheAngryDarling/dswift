//
//  executeSwift.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-21.
//

import Foundation
import SwiftPatches

extension Commands {

    /// Execute swift command
    static func commandSwift(_ args: [String]) -> Int32 {
        if args.contains("--help") {
            let task = Process()
            
            task.executable = URL(fileURLWithPath: settings.swiftPath)
            task.arguments = args
            
            let pipe = Pipe()
            defer {
                pipe.fileHandleForReading.closeFile()
                pipe.fileHandleForWriting.closeFile()
            }
            //#if os(macOS)
            //task.standardInput = FileHandle.nullDevice
            //#endif
            task.standardOutput = pipe
            task.standardError = pipe
            
            try! task.execute()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            var str = String(data: data, encoding: .utf8)!
            
            str = str.replacingOccurrences(of: "USAGE: swift", with: "USAGE: \(dswiftAppName)")
            if task.terminationStatus == 0 { print(str) }
            else { errPrint(str) }
            
            return task.terminationStatus
            
        } else {
            let task = Process()
            
            task.executable = URL(fileURLWithPath: settings.swiftPath)
            task.arguments = args
            
            try! task.execute()
            task.waitUntilExit()
            
            return task.terminationStatus
        }
        
       
    }
}
