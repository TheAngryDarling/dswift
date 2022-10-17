//
//  PackageDescription.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2018-12-04.
//

import Foundation
import SwiftPatches
import RegEx
import CodeTimer
import CLICapture
import PathHelpers

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
    /// Package Description Errors
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
        case unsupportedPackageSchemaVersion(schemaPath: String, version: String)
        case dependencyMissingLocalPath(name: String, url: String, version: String)
    }
    /// Internal Package Descriptions
    private struct Description: Codable {
        /// Package Target
        public struct Target: Codable {
            let c99name: String
            let module_type: String
            let name: String
            let path: FSPath
            let sources: [String]
            let type: String
        }
        /// Name of package
        let name: String
        /// Path of package
        let path: FSPath
        /// List of targets
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
    
    /// Package Target
    public struct Target {
        public let c99name: String
        public let module_type: String
        public let name: String
        public let path: FSPath
        public let pkgConfig: String?
        public let providers: Dictionary<String, Array<String>>
        public let sources: [String]
        public let type: String
    }
    
    fileprivate struct _Dependency: Decodable {
        private enum CodingKeys: String, CodingKey {
            case name
            case url
            case version
            case path
            case dependencies
        }
        let name: String
        let url: String
        let version: String
        let path: FSPath?
        let dependencies: [_Dependency]
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.url = try container.decode(String.self, forKey: .url)
            self.version = try container.decode(String.self, forKey: .version)
            let sPath = try container.decode(String.self, forKey: .path)
            if !sPath.isEmpty { self.path = FSPath(sPath) }
            else { self.path = nil }
            self.dependencies = try container.decode([_Dependency].self, forKey: .dependencies)
        }
    }
    /// Package Dependency
    public struct Dependency {
        private let p: Any?
        fileprivate var parent: Dependency? { return self.p as? Dependency }
        public let name: String
        public let url: String
        public let version: String
        public let path: FSPath
        public let description: PackageDescription?
        public private(set) var dependencies: [Dependency]
        
        fileprivate init(_ dependency: _Dependency,
                         swiftCLI: CLICapture,
                         havingParent parent: Dependency? = nil,
                         preloadedPackageDescriptions: inout [PackageDescription],
                         console: Console? = nil) throws {
            guard let depPath = dependency.path else {
                throw Error.dependencyMissingLocalPath(name: dependency.name,
                                                       url: dependency.url,
                                                       version: dependency.version)
            }
            self.p = parent
            self.name = dependency.name
            self.url = dependency.url
            self.version = dependency.version
            self.path = depPath
            if let d = preloadedPackageDescriptions.first(where: { return $0.path == depPath }) {
                self.description = d
            } else {
                //print("Loading Dependency['\(dependency.name)'] description")
                self.description = try PackageDescription.init(swiftCLI: swiftCLI,
                                                               packagePath: self.path,
                                                               loadDependencies: false,
                                                               preloadedPackageDescriptions: &preloadedPackageDescriptions,
                                                               console: console)
                }
                
                self.dependencies = []
                
                self.dependencies = try self.loadDependencies(from: dependency,
                                                              preloadedPackageDescriptions: &preloadedPackageDescriptions,
                                                              swiftCLI: swiftCLI,
                                                              console: console)
        }
        
        private func loadDependencies(from dependency: _Dependency,
                                      preloadedPackageDescriptions: inout [PackageDescription],
                                      swiftCLI: CLICapture,
                                      console: Console? = nil) throws -> [Dependency] {
            var rtn: [Dependency] = []
            var err: Swift.Error? = nil
            
            //let opQueue = OperationQueue()
            
            for dep in dependency.dependencies {
                if !self.hasExistingDependency(dep) {
                    //opQueue.addOperation {
                        do {
                            rtn.append(try Dependency(dep,
                                                      swiftCLI: swiftCLI,
                                                      havingParent: self,
                                                      preloadedPackageDescriptions: &preloadedPackageDescriptions,
                                                      console: console))
                        } catch {
                            err = error
                            //opQueue.cancelAllOperations()
                        }
                   // }
                }
            }
            //opQueue.waitUntilAllOperationsAreFinished()
            
            if let e = err {
                throw e
            }
            
            return rtn
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
    ///Name of the Package
    public let name: String
    /// Path of the package
    public let path: FSPath
    /// Package Config
    public let pkgConfig: String?
    /// Dependend Package Providers / Packages
    public let providers: Dictionary<String, Array<String>>
    /// Package Targets
    public let targets: [Target]
    /// Package Dependencies
    public let dependencies: [Dependency]?
    /// Gets all providers/packages in this project
    public var uniqueProviders: Dictionary<String, Array<String>> {
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
        
        for dependency in (self.dependencies ?? []) {
            guard let description = dependency.description else { continue }
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
    
    /// Create new Package Description
    /// - Parameters:
    ///   - swiftCLI: CLI Capture object used to execute Swift commands
    ///   - packagePath: Path the the swift project (Folder only)
    ///   - loadDependencies: Indicator if should load list of package dependencies
    ///   - preloadedPackageDescriptions: An array of already loaded package dependencies
    ///   - console: Console to write detailed loading information
    public init(swiftCLI: CLICapture,
                packagePath: FSPath = FSPath(FileManager.default.currentDirectoryPath),
                loadDependencies: Bool,
                preloadedPackageDescriptions: inout [PackageDescription],
                console: Console? = nil) throws {
        console?.printVerbose("Loading Package['\(packagePath.lastComponent)'] description")
        if !packagePath.exists() {
            throw Error.missingPackageFolder(packagePath.string)
        }
        
        let packageFilePath = packagePath.appendingComponent("Package.swift")
        if !packageFilePath.exists() {
            throw Error.missingPackageFile(packageFilePath.string)
        }
        console?.printVerbose("Loading Package['\(packagePath.lastComponent)'] description json")
        var desc: Description! = nil
        let decoder = JSONDecoder()
        var data: Data = Data()
        // a copy of the original data for error display purposes
        var displayData: Data = Data()
        // Setup to retry getting the package description since
        // on occasion it fails for various reasons like
        // when needing to download / redownload dependencies
        for retryCount in 0..<2 {
            let isLastTry = (retryCount == 1)
            if retryCount > 0 {
                console?.printDebug("Retrying to load Package['\(packagePath.lastComponent)']")
            }
            
            let pkgDescribeResponse = try swiftCLI.waitAndCaptureDataResponse(arguments: ["package",
                                                                                            "describe",
                                                                                            "--type",
                                                                                            "json"],
                                                                              currentDirectory: packagePath.url,
                                                                              outputOptions: .captureAll,
                                                                              withDataType: Data.self)
            
            if pkgDescribeResponse.exitStatusCode != 0 {
                let output: String? = String(optData: pkgDescribeResponse.output,
                                             encoding: .utf8)
                //if let describeStr = pkgDescribeResponse.output,
                if let describeStr = output,
                   let match = try! describeStr.firstMatch(pattern: "requires a minimum Swift tools version of (?<minVer>(\\d+(\\.\\d+(\\.\\d+)?)?)) \\(currently (?<currentVer>\\d+(\\.\\d+(\\.\\d+)?)?)\\)"),
                    //let match = m,
                    let minVer = match.value(withName: "minVer"),
                    let currentVer = match.value(withName: "currentVer") {
                    throw Error.minimumSwiftNotMet(current: currentVer, required: minVer)
                } else if let describeStr = output,
                          let match = try! describeStr.firstMatch(pattern: "unable to restore state from (?<schemaPath>.+/dependencies-state.json; unsupported schema version (?<schemaVer>.+)"),
                          let schemaPath = match.value(withName: "schemaPath"),
                          let schemaVer = match.value(withName: "schemaVer") {
                    throw Error.unsupportedPackageSchemaVersion(schemaPath: schemaPath,
                                                                version: schemaVer)
                }
                throw Error.unableToLoadDescription(packagePath.string,
                                                    output/*pkgDescribeResponse.output*/)
            }
            
            
            
            console?.printVerbose("Parsing Package['\(packagePath.lastComponent)'] json")
            data =  pkgDescribeResponse.out ?? Data()
            displayData = data
            
            //print("Decoding Package['\(packagePath.lastComponent)'] json")
            
            do {
                // if data does not start with '{' then we will stry and strip out
                // everything before it
                PackageDescription.fixJSON(&data)
                
                console?.printVerbose("Decoding Package['\(packagePath.lastComponent)'] json")
                desc = try decoder.decode(Description.self, from: data)
                console?.printVerbose("Decoded Package['\(packagePath.lastComponent)'] json")
                break
            } catch {
                // try seeing of the expected json is within the output
                if !isLastTry,
                   var jsonString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   jsonString.hasSuffix("}"),
                   let r = jsonString.range(of: "{") {
                    jsonString = String(jsonString[r.upperBound...])
                    if let dta = jsonString.data(using: .utf8) {
                        console?.printVerbose("Decoding Package['\(packagePath.lastComponent)'] json secondary attempt")
                        if let d = try? decoder.decode(Description.self, from: dta) {
                            desc = d
                            console?.printVerbose("Decoded Package['\(packagePath.lastComponent)'] json secondary attempt")
                            break
                        }
                    }
                }
                if isLastTry {
                    // If we're on our last try we will throw the error
                    // otherwise we will retry again
                    throw Error.unableToTransformDescriptionIntoObjects(error,
                                                                        displayData,
                                                                        String(data: displayData,
                                                                               encoding: .utf8))
                }
            }
        }
        
        guard desc != nil else {
            // This should not happen because
            // it should fail earlier if unable to load package description
            throw Error.unableToLoadDescription(packagePath.string,
                                                nil)
        }
        
        console?.printVerbose("Loading Package['\(packagePath.lastComponent)'] dump")
        let pkgDumpResponse = try swiftCLI.waitAndCaptureDataResponse(arguments: ["package",
                                                                                  "dump-package"],
                                                                      currentDirectory: packagePath.url,
                                                                      outputOptions: .captureAll,
                                                                      withDataType: Data.self)
        
        data = pkgDumpResponse.out ?? Data()
        displayData = data
        
        if pkgDumpResponse.exitStatusCode != 0 {
            let output = String(optData: pkgDumpResponse.output,
                                encoding: .utf8)
            
            // If output contains "unable to restore state from" then we're still good
            if !(output?.contains("unable to restore state from") ?? false) {
            
                throw Error.unableToLoadDescription(packagePath.string,
                                                    output)
            }
        }
        
        let dump: PackageDump!
        do {
            // if data does not start with '{' then we will stry and strip out
            // everything before it
            PackageDescription.fixJSON(&data)
            
            console?.printVerbose("Decoding Package['\(packagePath.lastComponent)'] dump")
            dump = try decoder.decode(PackageDump.self, from: data)
            console?.printVerbose("Decoded Package['\(packagePath.lastComponent)'] dump")
        } catch {
            throw Error.unableToTransformPackageDumpIntoObjects(error,
                                                                displayData,
                                                                String(data: displayData,
                                                                       encoding: .utf8))
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
            self.dependencies = nil
            preloadedPackageDescriptions.append(self)
            return
        }
        
        let depTaskResponse = try swiftCLI.waitAndCaptureDataResponse(arguments: ["package",
                                                                                    "show-dependencies",
                                                                                    "--format",
                                                                                    "json"],
                                                                        currentDirectory: packagePath.url,
                                                                        outputOptions: .captureAll,
                                                                      withDataType: Data.self)
        
        console?.printVerbose("Parsing Package['\(packagePath.lastComponent)'] dependencies")
        data = depTaskResponse.out ?? Data()
        displayData = data
        if depTaskResponse.exitStatusCode != 0 {
            let output = String(optData: depTaskResponse.output,
                                encoding: .utf8)
            
            /// If output contains "unable to restore state from" then we're still good
            if !(output?.contains("unable to restore state from") ?? false) {
            
                throw Error.unableToLoadDependencies(packagePath.string,
                                                    output)
            }
        }
        
        
        console?.printVerbose("Decoding Package['\(packagePath.lastComponent)'] dependencies")
        
        let dep: _Dependency!
        do {
            PackageDescription.fixJSON(&data)
            dep = try decoder.decode(_Dependency.self, from: data)
        } catch {
            throw Error.unableToTransformDependenciesIntoObjects(error,
                                                                 displayData,
                                                                 String(data: displayData,
                                                                        encoding: .utf8))
        }
        var deps: [Dependency] = []
        //var err: Swift.Error? = nil
        
        console?.printVerbose("Loading Package['\(packagePath.lastComponent)'] Dependency Details")
        //let opQueue = OperationQueue()
        
        for d in dep.dependencies {
            do {
                //print("Trying to load dependency '\(d.name)'")
                deps.append(try Dependency(d,
                                           swiftCLI: swiftCLI,
                                           preloadedPackageDescriptions: &preloadedPackageDescriptions,
                                            console: console))
            } catch {
                //err = error
                //opQueue.cancelAllOperations()
                throw error
            }
        }
        //opQueue.waitUntilAllOperationsAreFinished()
        /*if let e = err {
            throw e
        }*/
        self.dependencies = deps
        preloadedPackageDescriptions.append(self)
    }
    
    /// Create new Package Description
    /// - Parameters:
    ///   - swiftCLI: CLI Capture object used to execute Swift commands
    ///   - packagePath: Path the the swift project (Folder only)
    ///   - loadDependencies: Indicator if should load list of package dependencies
    ///   - console: Console to write detailed loading information
    public init(swiftCLI: CLICapture,
                packagePath: FSPath = FSPath(FileManager.default.currentDirectoryPath),
                loadDependencies: Bool,
                console: Console? = nil) throws {
        var preloadedPackageDescriptions: [PackageDescription] = []
        try self.init(swiftCLI: swiftCLI,
                      packagePath: packagePath,
                      loadDependencies: loadDependencies,
                      preloadedPackageDescriptions: &preloadedPackageDescriptions,
                      console: console)
    }
    
    
    /// Create new Package Description
    /// - Parameters:
    ///   - swiftPath: Path to the swift executable, (Default: default location of swift)
    ///   - packagePath: Path the the swift project (Folder only)
    ///   - loadDependencies: Indicator if should load list of package dependencies
    ///   - preloadedPackageDescriptions: An array of already loaded package dependencies
    ///   - fileManager: The file manager to use when accessing file information
    ///   - console: Console to write detailed loading information
    public init(swiftPath: FSPath = DSwiftSettings.defaultSwiftPath,
                packagePath: FSPath = FSPath(FileManager.default.currentDirectoryPath),
                loadDependencies: Bool,
                preloadedPackageDescriptions: inout [PackageDescription],
                using fileManager: FileManager = .default,
                console: Console) throws {
        if !swiftPath.exists(using: fileManager) {
            throw Error.missingSwift(swiftPath.string)
        }
        
        let swiftCLI = CLICapture.init(outputLock: Console.sharedOutputLock,
                                       createProcess: SwiftCLIWrapper.newSwiftProcessMethod(swiftURL: swiftPath.url))
        
        try self.init(swiftCLI: swiftCLI,
                      packagePath: FSPath(packagePath.string),
                      loadDependencies: loadDependencies,
                      preloadedPackageDescriptions: &preloadedPackageDescriptions,
                      console: console)
        
    }
    
    /// Create new Package Description
    /// - Parameters:
    ///   - swiftPath: Path to the swift executable, (Default: default location of swift)
    ///   - packagePath: Path the the swift project (Folder only)
    ///   - loadDependencies: Indicator if should load list of package dependencies
    ///   - fileManager: The file manager to use when accessing file information
    ///   - console: Console to write detailed loading information
    public init(swiftPath: FSPath = DSwiftSettings.defaultSwiftPath,
                packagePath: FSPath = FSPath(FileManager.default.currentDirectoryPath),
                loadDependencies: Bool,
                using fileManager: FileManager = .default,
                console: Console) throws {
        
        var preloadedPackageDescriptions: [PackageDescription] = []
        try self.init(swiftPath: swiftPath,
                      packagePath: packagePath,
                      loadDependencies: loadDependencies,
                      preloadedPackageDescriptions: &preloadedPackageDescriptions,
                      using: fileManager,
                      console: console)
    }
    
    internal static func fixJSON(_ data: inout Data) {
        // ensure the first byte in the data bloc is not '{'
        guard data[0] != 123 /* '{' */,
              let startOfJSON = data.firstIndex(of: 123), // find the first '{'
              let endOfJSON = data.lastIndex(of: 125) /* '}' */ else { // find the last '}'
            return
        }
        data = Data(data[startOfJSON...endOfJSON])
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
            case .unsupportedPackageSchemaVersion(schemaPath: let path, version: let ver):
                return "unable to restore state from \(path); unsupported schema version \(ver)"
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
