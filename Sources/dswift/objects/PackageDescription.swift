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
        case unableToLoadDescription(String, String?)
        case unableToLoadDependencies(String, String?)
        case unableToTransformDescriptionIntoObjects(Swift.Error, Data, String?)
        case unableToTransformPackageDumpIntoObjects(Swift.Error, Data, String?)
        case unableToTransformDependenciesIntoObjects(Swift.Error, Data, String?)
        case minimumSwiftNotMet(current: String, required: String)
        case dependencyMissingLocalPath(name: String, url: String, version: String)
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
    
    fileprivate struct _Dependency: Codable {
        let name: String
        let url: String
        let version: String
        let path: String
        let dependencies: [_Dependency]
    }
    
    public struct Dependency {
        private let p: Any?
        fileprivate var parent: Dependency? { return self.p as? Dependency }
        let name: String
        let url: String
        let version: String
        let path: String
        let description: PackageDescription?
        public private(set) var dependencies: [Dependency]
        
        fileprivate init(_ dependency: _Dependency,
                         swiftPath: String,
                         havingParent parent: Dependency? = nil) throws {
            guard !dependency.path.isEmpty else {
                throw Error.dependencyMissingLocalPath(name: dependency.name,
                                                       url: dependency.url,
                                                       version: dependency.version)
            }
            self.p = parent
            self.name = dependency.name
            self.url = dependency.url
            self.version = dependency.version
            self.path = dependency.path
            self.description = try PackageDescription(swiftPath: swiftPath,
                                                      packagePath: self.path,
                                                      loadDependencies: false)
            
            self.dependencies = []
            
            for dep in dependency.dependencies {
                // Stop recursive dependancies
                if !self.hasExistingDependency(dep) {
                    self.dependencies.append(try Dependency(dep, swiftPath: swiftPath, havingParent: self))
                }
            }
        }
        
        private func contains(_ dep: _Dependency) -> Bool {
            for subDep in self.dependencies {
                if (subDep.name == dep.name && subDep.url == dep.url && subDep.version == dep.version)  {
                    return true
                } else if subDep.contains(dep) {
                    return true
                }
            }
            return false
        }
        
        private func hasExistingDependency(_ dep: _Dependency) -> Bool {
            guard let parent = self.parent else { return false }
            guard !(parent.name == dep.name && parent.url == dep.url && parent.version == dep.version) else {
                return true
            }
            guard !parent.contains(dep) else { return true }
            
            return parent.hasExistingDependency(dep)
            
        }
    }
    
    let name: String
    let path: String
    let pkgConfig: String?
    let providers: Dictionary<String, Array<String>>
    let targets: [Target]
    let dependencies: [Dependency]
    /// Gets all providers/packages in this project
    var uniqueProviders: Dictionary<String, Array<String>> {
        func combind(_ src: Array<String>, _ dest: Array<String>) -> Array<String> {
            var rtn = src
            for val in dest {
                if !rtn.contains(val) {
                    rtn.append(val)
                }
            }
            return rtn.sorted()
        }
        var rtn = self.providers
        
        for target in self.targets {
            for (manager, packages) in target.providers {
                guard let ary = rtn[manager] else {
                    rtn[manager] = packages.sorted()
                    continue
                }
                rtn[manager] = combind(ary, packages)
            }
        }
        
        for dependancy in self.dependencies {
            guard let description = dependancy.description else { continue }
            for (manager, packages) in description.uniqueProviders {
                guard let ary = rtn[manager] else {
                    rtn[manager] = packages.sorted()
                    continue
                }
                rtn[manager] = combind(ary, packages)
            }
        }
        
        return rtn
    }
    
    public init(swiftPath: String = DSwiftSettings.defaultSwiftPath,
                packagePath: String = FileManager.default.currentDirectoryPath,
                loadDependencies: Bool) throws {
        if !FileManager.default.fileExists(atPath: swiftPath) { throw Error.missingSwift(swiftPath) }
        if !FileManager.default.fileExists(atPath: packagePath) { throw Error.missingPackageFolder(packagePath) }
        
        let packageFileURL = URL(fileURLWithPath: packagePath).appendingPathComponent("Package.swift")
        if !FileManager.default.fileExists(atPath: packagePath) {
            throw Error.missingPackageFile(packageFileURL.path)
        }
        
        let task = newProcess()
        
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
        
        var data = pipe.fileHandleForReading.readDataToEndOfFile()
        let responseStr = String(data: data, encoding: .utf8)
        
        if task.terminationStatus != 0 {
            
            if let describeStr = responseStr,
                let m = try? describeStr.firstMatch(pattern: "requires a minimum Swift tools version of (?<minVer>(\\d+(\\.\\d+(\\.\\d+)?)?)) \\(currently (?<currentVer>\\d+(\\.\\d+(\\.\\d+)?)?)\\)"),
                let match = m,
                let minVer = match.value(withName: "minVer"),
                let currentVer = match.value(withName: "currentVer") {
                throw Error.minimumSwiftNotMet(current: currentVer, required: minVer)
            }
            throw Error.unableToLoadDescription(packagePath, responseStr)
        }
        
        // Convert output to utf8 string
        if let describeStr = responseStr {
            
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
        
        let dumpTask = newProcess()
        
        dumpTask.executable = URL(fileURLWithPath: swiftPath)
        dumpTask.currentDirectory = URL(fileURLWithPath: packagePath)
        dumpTask.arguments = ["package", "dump-package"]
        
        #if os(macOS)
        // Send errors to null
        dumpTask.standardInput = FileHandle.nullDevice
        #endif
        let dumpPipe = Pipe()
        let dumpErrPipe = Pipe()
        dumpTask.standardOutput = dumpPipe
        dumpTask.standardError = dumpErrPipe //FileHandle.nullDevice //dumpPipe
        try dumpTask.execute()
        dumpTask.waitUntilExit()
        
        if dumpTask.terminationStatus != 0 {
            throw Error.unableToLoadDescription(packagePath,
                                                String(data: dumpPipe.fileHandleForReading.readDataToEndOfFile(),
                                                       encoding: .utf8))
        }
        
        data = dumpPipe.fileHandleForReading.readDataToEndOfFile()
        if var dtaStr = String(data: data, encoding: .utf8) {
            if dtaStr.hasPrefix("unable to restore state from") {
                dtaStr = dtaStr.split(separator: "\n").dropFirst().map(String.init).joined(separator: "\n")
                if let newDta = dtaStr.data(using: .utf8) {
                    data = newDta
                }
            }
        }
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
        
        guard loadDependencies else {
            self.dependencies = []
            return
        }
        
        let depTask = newProcess()
        
        depTask.executable = URL(fileURLWithPath: swiftPath)
        depTask.currentDirectory = URL(fileURLWithPath: packagePath)
        depTask.arguments = ["package", "show-dependencies", "--format", "json"]
        
        #if os(macOS)
        // Send errors to null
        depTask.standardInput = FileHandle.nullDevice
        #endif
        let depPipe = Pipe()
        depTask.standardOutput = depPipe
        depTask.standardError = depPipe
        
        try depTask.execute()
        depTask.waitUntilExit()
        
        if depTask.terminationStatus != 0 {
            throw Error.unableToLoadDependencies(packagePath,
                                                 String(data: depPipe.fileHandleForReading.readDataToEndOfFile(),
                                                       encoding: .utf8))
        }
        
        data = depPipe.fileHandleForReading.readDataToEndOfFile()
        if var dtaStr = String(data: data, encoding: .utf8) {
            if dtaStr.hasPrefix("unable to restore state from") {
                dtaStr = dtaStr.split(separator: "\n").dropFirst().map(String.init).joined(separator: "\n")
                if let newDta = dtaStr.data(using: .utf8) {
                    data = newDta
                }
            }
        }
        let dep: _Dependency!
        do {
            dep = try decoder.decode(_Dependency.self, from: data)
        } catch {
            throw Error.unableToTransformDependenciesIntoObjects(error, data, String(data: data, encoding: .utf8))
        }
        
        self.dependencies = try dep.dependencies.map({ return try Dependency($0, swiftPath: swiftPath) })
    }
}


extension PackageDescription.Error: CustomStringConvertible {
    
    public var description: String {
        switch self {
            case .missingSwift(let path): return "Swift not found at \(path)"
            case .missingPackageFolder(let path): return "Package folder not found at \(path)"
            case .missingPackageFile(let path): return "Missing file at \(path)"
            case .unableToLoadDescription(let path, let response):
                var rtn = "Unable to load package description for \(path)"
                if let r = response { rtn += "\n" + r }
                return rtn
            case .unableToLoadDependencies(let path, let response):
                var rtn = "Unable to load package dependencies for \(path)"
                if let r = response { rtn += "\n" + r }
                return rtn
            case .unableToTransformDescriptionIntoObjects(let err, _, let str):
                var rtn: String = "Unable to parse package description\nError: \(err)"
                if let s = str { rtn += "\nText: \(s)" }
                return rtn
            
            case .unableToTransformPackageDumpIntoObjects(let err, _, let str):
                var rtn: String = "Unable to parse package dump\nError: \(err)"
                if let s = str { rtn += "\nText: \(s)" }
                return rtn
            case .unableToTransformDependenciesIntoObjects(let err, _, let str):
                var rtn: String = "Unable to parse dependencies\nError: \(err)"
                if let s = str { rtn += "\nText: \(s)" }
                return rtn
            case .minimumSwiftNotMet(current: let current, required: let required):
                return "Requires a minimum Swift tools version of \(required) (currently \(current))"
            case .dependencyMissingLocalPath(name: let name, url: let url, version: let version):
                 var rtn = "Dependency \(name) having url \(url)"
                 if version != "unspecified" {
                    rtn += " with version \(version)"
                }
                rtn += " is missing locally"
                return rtn
        }
    }
}
