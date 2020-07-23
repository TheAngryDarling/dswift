//
//  PackageDescription.swift
//  dswift
//
//  Created by Tyler Anger on 2018-12-04.
//

import Foundation
import SwiftPatches
import RegEx

fileprivate extension Array where Element == Dictionary<String, Array<Array<String>>> {
    // Convert providers to a more normalized structure
    func toProvider() -> Dictionary<String, Array<String>> {
        var rtn = Dictionary<String, Array<String>>()
        for element in self {
            for (key, vals) in element {
                guard var ary = rtn[key] else {
                    var valsAry = Array<String>()
                    for valAry in vals {
                        for val in valAry {
                            if !valsAry.contains(val) {
                                valsAry.append(val)
                            }
                        }
                        
                    }
                    rtn[key] = valsAry.sorted()
                    continue
                }
                for valAry in vals {
                    for val in valAry {
                        if !ary.contains(val) {
                            ary.append(val)
                        }
                    }
                }
                rtn[key] = ary.sorted()
            }
        }
        return rtn
    }
}
fileprivate extension Array where Element == PackageDescription.PackageDump.LinuxProvider {
    func toProvider() -> Dictionary<String, Array<String>> {
        var rtn = Dictionary<String, Array<String>>()
        for provider in self {
            guard var values = rtn[provider.name] else {
                rtn[provider.name] = provider.values.sorted()
                continue
            }
            for val in provider.values {
                if !values.contains(val) {
                    values.append(val)
                }
            }
            rtn[provider.name] = values.sorted()
        }
        return rtn
    }
}
/// The package description of the SwiftPM project
public struct PackageDescription {
    public enum Error: Swift.Error {
        case missingSwift(String)
        case missingPackageFolder(String)
        case missingPackageFile(String)
        case unableToLoadDescription(String)
        case unableToTransformDescriptionIntoObjects(Swift.Error, Data, String?)
        case unableToTransformPackageDumpIntoObjects(Swift.Error, Data, String?)
        case minimumSwiftNotMet(current: String, required: String)
    }
    
    private struct Description: Codable {
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
    }
    
    
    fileprivate struct PackageDump: Codable {
        fileprivate struct LinuxProvider: Codable {
            let name: String
            let values: [String]
        }
        #if os(OSX) || os(macOS)
        typealias Providers = [Dictionary<String, Array<Array<String>>>]
        #else
        typealias Providers = [LinuxProvider]
        #endif
        struct Target: Codable {
            
            let name: String
            let pkgConfig: String?
            let providers: Providers?
        }
        let name: String
        let pkgConfig: String?
        let providers: Providers?
        let targets: [Target]
        
        func getTarget(_ name: String) -> Target? {
            return self.targets.first(where: { $0.name == name })
        }
    }
    
    
    public struct Target {
        let c99name: String
        let module_type: String
        let name: String
        let path: String
        let pkgConfig: String?
        let providers: Dictionary<String, Array<String>>
        let sources: [String]
        let type: String
    }
    
    let name: String
    let path: String
    let pkgConfig: String?
    let providers: Dictionary<String, Array<String>>
    let targets: [Target]
    /// Gets all providers/packages in this project
    var uniqueProviders: Dictionary<String, Array<String>> {
        var rtn = self.providers
        
        for target in targets {
            for (manager, packages) in target.providers {
                guard var ary = rtn[manager] else {
                    rtn[manager] = packages.sorted()
                    continue
                }
                for package in packages {
                    if !ary.contains(package) {
                        ary.append(package)
                    }
                }
                rtn[manager] = ary.sorted()
            }
        }
        
        return rtn
    }
    
    public init(swiftPath: String = "/usr/bin/swift",
                packagePath: String = FileManager.default.currentDirectoryPath) throws {
        if !FileManager.default.fileExists(atPath: swiftPath) { throw Error.missingSwift(swiftPath) }
        if !FileManager.default.fileExists(atPath: packagePath) { throw Error.missingPackageFolder(packagePath) }
        
        let packageFileURL = URL(fileURLWithPath: packagePath).appendingPathComponent("Package.swift")
        if !FileManager.default.fileExists(atPath: packagePath) {
            throw Error.missingPackageFile(packageFileURL.path)
        }
        
        let task = Process()
        
        task.executable = URL(fileURLWithPath: swiftPath)
        task.currentDirectory = URL(fileURLWithPath: packagePath)
        task.arguments = ["package", "describe", "--type", "json"]
        
        #if os(macOS)
         // Send errors to null
        task.standardInput = FileHandle.nullDevice
        #endif
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        try task.execute()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            if let describeStr = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8),
                let m = try? describeStr.firstMatch(pattern: "requires a minimum Swift tools version of (?<minVer>(\\d+(\\.\\d+(\\.\\d+)?)?)) \\(currently (?<currentVer>\\d+(\\.\\d+(\\.\\d+)?)?)\\)"),
                let match = m,
                let minVer = match.value(withName: "minVer"),
                let currentVer = match.value(withName: "currentVer") {
                throw Error.minimumSwiftNotMet(current: currentVer, required: minVer)
            }
            throw Error.unableToLoadDescription(packagePath)
        }
        
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
        
        
        let desc: Description!
        let decoder = JSONDecoder()
        do {
            desc = try decoder.decode(Description.self, from: data)
        } catch {
            throw Error.unableToTransformDescriptionIntoObjects(error, data, String(data: data, encoding: .utf8))
        }
        
        let dumpTask = Process()
        
        dumpTask.executable = URL(fileURLWithPath: swiftPath)
        dumpTask.currentDirectory = URL(fileURLWithPath: packagePath)
        dumpTask.arguments = ["package", "dump-package"]
        
        #if os(macOS)
        // Send errors to null
        dumpTask.standardInput = FileHandle.nullDevice
        #endif
        let dumpPipe = Pipe()
        dumpTask.standardOutput = dumpPipe
        task.standardError = dumpPipe
        
        try dumpTask.execute()
        dumpTask.waitUntilExit()
        
        if dumpTask.terminationStatus != 0 { throw Error.unableToLoadDescription(packagePath) }
        
        data = dumpPipe.fileHandleForReading.readDataToEndOfFile()
        let dump: PackageDump!
        do {
            dump = try decoder.decode(PackageDump.self, from: data)
        } catch {
            throw Error.unableToTransformPackageDumpIntoObjects(error, data, String(data: data, encoding: .utf8))
        }
        
        self.name = desc.name
        self.path = desc.path
        self.pkgConfig = dump.pkgConfig
        self.providers = dump.providers?.toProvider() ?? Dictionary<String, Array<String>>()
        
        var tgts: [Target] = []
        
        for target in desc.targets {
            let tmpTarget = dump.getTarget(target.name)
            
            let providers: Dictionary<String, Array<String>> = tmpTarget?.providers?.toProvider() ?? Dictionary<String, Array<String>> ()
            
            tgts.append(Target(c99name: target.c99name,
                               module_type: target.module_type,
                               name: target.name,
                               path: target.path,
                               pkgConfig: tmpTarget?.pkgConfig,
                               providers: providers,
                               sources: target.sources,
                               type: target.type))
        }
        
        self.targets = tgts
        
    }
}


extension PackageDescription.Error: CustomStringConvertible {
    
    public var description: String {
        switch self {
            case .missingSwift(let path): return "Swift not found at \(path)"
            case .missingPackageFolder(let path): return "Package folder not found at \(path)"
            case .missingPackageFile(let path): return "Missing file at \(path)"
            case .unableToLoadDescription(let path): return "Unable to load package description for \(path)"
            case .unableToTransformDescriptionIntoObjects(let err, _, let str):
                var rtn: String = "Unable to parse package description\nError: \(err)"
                if let s = str { rtn += "\nText: \(s)" }
                return rtn
            
            case .unableToTransformPackageDumpIntoObjects(let err, _, let str):
                var rtn: String = "Unable to parse package dump\nError: \(err)"
                if let s = str { rtn += "\nText: \(s)" }
                return rtn
            
            case .minimumSwiftNotMet(current: let current, required: let required):
                return "Requires a minimum Swift tools version of \(required) (currently \(current))"
        }
    }
}
