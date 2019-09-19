//
//  PackageDescription.swift
//  dswift
//
//  Created by Tyler Anger on 2018-12-04.
//

import Foundation
import SwiftPatches

/// The package description of the SwiftPM project
public struct PackageDescription: Codable {
    public enum Error: Swift.Error {
        case missingSwift(String)
        case missingPackageFolder(String)
        case missingPackageFile(String)
        case unableToLoadDescription(String)
        case unableToTransformDescriptionIntoObjects(Swift.Error, Data, String?)
    }
    public struct Target: Codable {
        let c99name: String
        let module_type: String
        let name: String
        let path: String
        let sources: [String]
        let type: String
    }
    
    let name: String
    let path: String
    let targets: [Target]
    
    public init(swiftPath: String = "/usr/bin/swift",
                packagePath: String = FileManager.default.currentDirectoryPath) throws {
        if !FileManager.default.fileExists(atPath: swiftPath) { throw Error.missingSwift(swiftPath) }
        if !FileManager.default.fileExists(atPath: packagePath) { throw Error.missingPackageFolder(packagePath) }
        
        let packageFileURL = URL(fileURLWithPath: packagePath).appendingPathComponent("Package.swift")
        if !FileManager.default.fileExists(atPath: packagePath) { throw Error.missingPackageFile(packageFileURL.path) }
        
        let task = Process()
        
        task.executable = URL(fileURLWithPath: swiftPath)
        task.currentDirectory = URL(fileURLWithPath: packagePath)
        task.arguments = ["package", "describe", "--type", "json"]
        
        let pipe = Pipe()
        #if os(macOS)
        task.standardInput = FileHandle.nullDevice
        #endif
        task.standardOutput = pipe
        // Send errors to null
        task.standardError = FileHandle.nullDevice
        //task.standardOutput = pipe
        
        try task.execute()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 { throw Error.unableToLoadDescription(packagePath) }
        
        var data = pipe.fileHandleForReading.readDataToEndOfFile()
        // Convert output to utf8 string
        if let describeStr = String(data: data, encoding: .utf8) {
            // Find the start of the json string {
            if let r = describeStr.range(of: "{") {
                // Create substring from the beginning of the json
                let jsonStr = String(describeStr[r.lowerBound...])
                // Convert back into data for decoding
                data = jsonStr.data(using: .utf8)!
            }
        }
        
        let decoder = JSONDecoder()
        do { self = try decoder.decode(PackageDescription.self, from: data) }
        catch { throw Error.unableToTransformDescriptionIntoObjects(error, data, String(data: data, encoding: .utf8)) }
    }
}
