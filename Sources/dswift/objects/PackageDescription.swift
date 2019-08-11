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
        case unableToTransformDescriptionIntoObjects(Swift.Error, Data)
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
        task.standardOutput = pipe
        
        try task.execute()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 { throw Error.unableToLoadDescription(packagePath) }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        let decoder = JSONDecoder()
        do { self = try decoder.decode(PackageDescription.self, from: data) }
        catch { throw Error.unableToTransformDescriptionIntoObjects(error, data) }
    }
}
