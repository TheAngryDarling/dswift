//
//  DynamicSourceCodeGenerator.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2018-12-04.
//

import Foundation
#if os(Linux)
import Dispatch
import Glibc
#endif
import SwiftPatches
import VersionKit
import XcodeProj
import RegEx
import CLICapture
import SynchronizeObjects
import PathHelpers


public class DynamicSourceCodeGenerator: DynamicGenerator {
    
    public class TagReplacementDetails {
        
        public class IncludeReplacement {
            /// The raw synchronized storage
            private let raw: SyncLockObj<[String: Any]> = .init(value: [:])
            
            public subscript(_ key: String) -> Any? {
                get { return self.raw[key] }
                set { self.raw[key] = newValue }
            }
            
            public subscript<T>(_ key: String, ofType type: T.Type) -> T? {
                get { return self.raw[key] as? T }
            }
            
            public var processedIncludeFiles: [String] {
                get { return self["included.files.processed", ofType: [String].self] ?? [] }
                set { self["included.files.processed"] = newValue }
            }
        }
        
        /// The raw synchronized storage
        private let raw: SyncLockObj<[String: Any]> = .init(value: [:])
        
        public subscript(_ key: String) -> Any? {
            get { return self.raw[key] }
            set { self.raw[key] = newValue }
        }
        
        public subscript<T>(_ key: String, ofType type: T.Type) -> T? {
            get { return self.raw[key] as? T }
        }
        
        public var includeReplacement: IncludeReplacement {
            get {
                if let r = self["replacement.include", ofType: IncludeReplacement.self] {
                    return r
                }
                
                let rtn = IncludeReplacement()
                self["replacement.include"] = rtn
                return rtn
            }
        }
        
        public init() { }
    }
    public class PreloadedDetails {
        
        public enum Errors: Swift.Error, CustomStringConvertible {
            case invalidDSwiftToolsVersionNumber(for: String, ver: String)
            
            public var description: String {
                switch self {
                    case .invalidDSwiftToolsVersionNumber(let path, let ver):
                        return "\(path): Invalid dswift-tools-version '\(ver)'"
                }
            }
        }
        
        public typealias DSWIFT_TOOLS_VERSION_PARSER = (_ path: FSPath,
                                                        _ source: String,
                                                        _ console: Console) throws -> Version.SingleVersion?
        
        public typealias DSWIFT_TAGS_PARSER = (_ path: FSPath,
                                               _ source: String,
                                               _ project: SwiftProject,
                                               _ console:  Console,
                                               _ fileManager: FileManager) throws -> [DSwiftTag]
        
        private let sourceContent: SyncLockObj<[String: (content: String, encoding: String.Encoding)]>
        
        private let sourceVersion: SyncLockObj<[String: Version.SingleVersion?]>
        private let parseDSwiftToolsVersion: DSWIFT_TOOLS_VERSION_PARSER
        
        private let dswiftTags: SyncLockObj<[String: [DSwiftTag]]>
        private let parseDSwiftTags: DSWIFT_TAGS_PARSER
        
        
        public init(sourceContent: [String: (content: String, encoding: String.Encoding)] = [:],
                    sourceVersion: [String: Version.SingleVersion?] = [:],
                    parseDSwiftToolsVersion: @escaping DSWIFT_TOOLS_VERSION_PARSER,
                    dswiftTags: [String: [DSwiftTag]] = [:],
                    parseDSwiftTags: @escaping DSWIFT_TAGS_PARSER) {
            //self.project = project
            self.sourceContent = .init(value: sourceContent)
            self.sourceVersion = .init(value: sourceVersion)
            self.parseDSwiftToolsVersion = parseDSwiftToolsVersion
            self.dswiftTags = .init(value: dswiftTags)
            self.parseDSwiftTags = parseDSwiftTags
        }
        
        public func getSourceContent(for path: FSPath,
                                     encoding: String.Encoding?,// = nil,
                                     console: Console = .null,
                                     using fileManager: FileManager) throws -> (content: String, encoding: String.Encoding) {
            return try self.sourceContent.lockingForWithValue { ptr in
                if let rtn = ptr.pointee[path.string] { return rtn }
                
                if let enc = encoding {
                    console.printVerbose("Reading file '\(path.lastComponent)' with encoding \(enc)", object: self)
                    let includeSrc = try String(contentsOf: path, encoding: enc, using: fileManager)
                    ptr.pointee[path.string] =  (content: includeSrc, encoding: enc)
                    return (content: includeSrc, encoding: enc)
                } else {
                    console.printVerbose("Reading file '\(path.lastComponent)'", object: self)
                    var enc: String.Encoding = .utf8
                    let includeSrc = try String(contentsOf: path, foundEncoding: &enc, using: fileManager)
                    
                    ptr.pointee[path.string] =  (content: includeSrc, encoding: enc)
                    return (content: includeSrc, encoding: enc)
                }
            }
            
        }
        
        public func getSourceContent(for path: FSPath,
                                     project: SwiftProject,
                                     console: Console = .null,
                                     using fileManager: FileManager) throws -> (content: String, encoding: String.Encoding) {
            return try self.getSourceContent(for: path,
                                             encoding: project.xcodeFile(at: path)?.encoding,
                                             console: console,
                                             using: fileManager)
        }
        
        
        
        public func getSourceDSwiftVersion(for path: FSPath,
                                           source: String,
                                           console: Console = .null) throws -> Version.SingleVersion? {
            
            //self.sourceVersionLock.lock()
            //defer { self.sourceVersionLock.unlock() }
            return try self.sourceVersion.lockingForWithValue { ptr -> Version.SingleVersion? in
                
                if let ver = ptr.pointee[path.string] { return ver }
                
                let ver = try self.parseDSwiftToolsVersion(path, source, console)
                
                ptr.pointee[path.string] = ver
                
                return ver
            }
            
        }
        
        public func getSourceDSwiftVersion(for path: FSPath,
                                           encoding: String.Encoding?,// = nil,
                                           console: Console = .null,
                                                 using fileManager: FileManager) throws -> Version.SingleVersion? {
            
            //self.sourceVersionLock.lock()
            //defer { self.sourceVersionLock.unlock() }
            
            return try self.sourceVersion.lockingForWithValue { ptr -> Version.SingleVersion? in
                if let ver = ptr.pointee[path.string] { return ver }
                
                let source = (try self.getSourceContent(for: path,
                                                        encoding: encoding,
                                                        console: console,
                                                        using: fileManager)).content
                
                let ver = try self.parseDSwiftToolsVersion(path, source, console)
                
                ptr.pointee[path.string] = ver
                
                return ver
            }
            
            
        }
        
        public func getSourceDSwiftVersion(for path: FSPath,
                                           project: SwiftProject,
                                           console: Console = .null,
                                           using fileManager: FileManager) throws -> Version.SingleVersion? {
            return try self.getSourceDSwiftVersion(for: path,
                                                   encoding: project.xcodeFile(at: path)?.encoding,
                                                   console: console,
                                                      using: fileManager)
        }
        public func getDSwiftTags(in path: FSPath,
                                  source: String,
                                  project: SwiftProject,
                                  console: Console = .null,
                                  using fileManager: FileManager) throws -> [DSwiftTag] {
            //self.dswiftTagsLock.lock()
            //defer { self.dswiftTagsLock.unlock() }
            return try self.dswiftTags.lockingForWithValue { ptr -> [DSwiftTag] in
                if let rtn = ptr.pointee[path.string] { return rtn }
                
                let rtn = try self.parseDSwiftTags(path,
                                                   source,
                                                   project,
                                                   console,
                                                   fileManager)
                ptr.pointee[path.string] = rtn
                return rtn
            }
        }
        
        public func getDSwiftTags(in path: FSPath,
                                  encoding: String.Encoding?,// = nil,
                                  project: SwiftProject,
                                  console: Console = .null,
                                  using fileManager: FileManager) throws -> [DSwiftTag] {
            //self.dswiftTagsLock.lock()
            //defer { self.dswiftTagsLock.unlock() }
            return try self.dswiftTags.lockingForWithValue { ptr -> [DSwiftTag] in
                if let rtn = ptr.pointee[path.string] { return rtn }
                
                let content = (try self.getSourceContent(for: path,
                                                         encoding: encoding,
                                                         console: console,
                                                            using: fileManager)).content
                
                let rtn = try self.parseDSwiftTags(path,
                                                   content,
                                                   project,
                                                   console,
                                                   fileManager)
                ptr.pointee[path.string] = rtn
                return rtn
            }
        }
        
        public func getDSwiftTags(in path: FSPath,
                                  project: SwiftProject,
                                  console: Console = .null,
                                  using fileManager: FileManager) throws -> [DSwiftTag] {
            return try self.getDSwiftTags(in: path,
                                          encoding: project.xcodeFile(at: path)?.encoding,
                                          project: project,
                                          console: console,
                                          using: fileManager)
        }
    }
    
    public enum Errors: Error, CustomStringConvertible {
        public enum FolderType {
            case project
            case sources
            case module
        }
      
        case swiftPathNotProvided
        case missingSwift(atPath: String)
        case missingSource(atPath: String)
        case couldNotCleanFolder(atPath: String, Swift.Error?)
        case couldNotCreateFolder(FolderType, atPath: String, Swift.Error?)
        case unableToGenerateSource(for: String, Swift.Error?)
        case unableToWriteFile(atPath: String, Swift.Error?)
        
        case mustBeFileURL(URL)
        case buildModuleFailed(for: String, withCode: Int, returingError: String?)
        case runModuleFailed(for: String, withCode: Int, returingError: String?)
        case unableToReadSTDOut
        
        case failedToGetContentsOfDir(atPath: String, Swift.Error)
        case failedToCreateDirectory(atPath: String, Swift.Error)
        case failedToCopyFile(atPath: String, to: String, Swift.Error)
        
        public var description: String {
            switch self {
                case .swiftPathNotProvided: return "No swift path provided"
                case .missingSwift(atPath: let path): return "Swift was not found at location '\(path)'"
                case .missingSource(atPath: let path): return "Missing source file '\(path)'"
                case .couldNotCleanFolder(atPath: let path, let err):
                    var rtn: String = "Could not clean compiled dswift files from '\(path)'"
                    if let e = err { rtn += ": \(e)" }
                    return rtn
                case .couldNotCreateFolder(let folderType, atPath: let path, let err):
                    var rtn: String = "Could not create folder (of type: \(folderType)) at in '\(path)'"
                    if let e = err { rtn += ": \(e)" }
                    return rtn
                case .unableToGenerateSource(for: let path, let err):
                    var rtn: String = "Unable to compile dswift file '\(path)'"
                    if let e = err {
                        if e is DynamicSourceCodeBuilder.Errors {
                           rtn = "\(e)"
                        } else {
                            rtn += ": \(e)"
                        }
                    }
                    return rtn
                case .unableToWriteFile(atPath: let path, let err):
                    var rtn: String = "Unable to write file '\(path)'"
                    if let e = err { rtn += ": \(e)" }
                    return rtn
                case .mustBeFileURL(let url):
                    return "URL '\(url)' must be a file url"
                case .buildModuleFailed(for: let path, withCode: let returnCode, returingError: let err):
                    var rtn: String = "Building '\(path)' failed with a return code \(returnCode)"
                    if let e = err { rtn += ": \(e)" }
                    return rtn
                case .runModuleFailed(for: let path, withCode: let returnCode, returingError: let err):
                    var rtn: String = "Running module '\(path)' failed with a return code \(returnCode)"
                    if let e = err { rtn += ": \(e)" }
                    return rtn
                case .unableToReadSTDOut: return "Unable to read from SDT Output"
                case .failedToGetContentsOfDir(atPath: let path, let err):
                    return "Unable to get contents of directory '\(path)': \(err)"
                case .failedToCreateDirectory(atPath: let path, let err):
                    return "Failed to create directory'\(path)': \(err)"
                case .failedToCopyFile(atPath: let path, to: let dest, let err):
                    return "Failed to copy file from '\(path)' to '\(dest)': \(err)"
            }
        }
    }
    
    
    
    private static let PACKAGE_FILE_CONTENTS: String = """
    // swift-tools-version:4.0
    // The swift-tools-version declares the minimum version of Swift required to build this package.

    import PackageDescription

    let package = Package(
        name: "{MODULENAME}",
        products: [
            // Products define the executables and libraries produced by a package, and make them visible to other packages.
            /*.library(
                name: "{MODULENAME}",
                type: .dynamic,
                targets: ["{MODULENAME}"]),*/
        ],
        dependencies: [
            // Dependencies declare other packages that this package depends on.
            // .package(url: /* package url */, from: "1.0.0"),
        ],
        targets: [
            // Targets are the basic building blocks of a package. A target can define a module or a test suite.
            // Targets can depend on other targets in this package, and on products in packages which this package depends on.
            .target(
                name: "{MODULENAME}",
                dependencies: []),
        ]
    )
    """
    
    
    public static let PACKAGE_FILE_ENCODING: String.Encoding = String.Encoding.utf8
    
    public var supportedExtensions: [FSExtension] { return [FSExtension("dswift")] }
    
    private static let CommonLibraryName: String = "LibraryGen"
    private let commonLibraryCounter = SyncLockObj<Int>(value: 0)
    
    private static let CommonClassName: String = "ClassGEN"
    private let commonClassCounter = SyncLockObj<Int>(value: 0)
    
    private let tempLocation: FSPath
    
    private let swiftCLI: CLICapture
    
    public let dswiftInfo: DSwiftInfo
    public let console: Console
    
    internal var preloadedDetails: PreloadedDetails
    
    public required init(swiftCLI: CLICapture,
                         dswiftInfo: DSwiftInfo,
                         tempDir: FSPath,
                         console: Console = .null) throws {
        self.swiftCLI = swiftCLI
        
        self.dswiftInfo = dswiftInfo
        self.preloadedDetails = PreloadedDetails(parseDSwiftToolsVersion: DynamicSourceCodeBuilder.parseDSwiftToolsVersion(from:source:console:),
                                                 parseDSwiftTags: DynamicSourceCodeBuilder.parseDSwiftTags(in:source:project:console:using:))
        self.console = console
        self.tempLocation = tempDir.appendingComponent(String.random() + "-\(ProcessInfo.processInfo.processIdentifier)")
    }
    
    public required init(swiftCLI: CLICapture,
                         dswiftInfo: DSwiftInfo,
                         console: Console = .null) throws {
        self.swiftCLI = swiftCLI
        
        self.dswiftInfo = dswiftInfo
        self.preloadedDetails = PreloadedDetails(parseDSwiftToolsVersion: DynamicSourceCodeBuilder.parseDSwiftToolsVersion(from:source:console:),
                                                 parseDSwiftTags: DynamicSourceCodeBuilder.parseDSwiftTags(in:source:project:console:using:))
        self.console = console
        self.tempLocation = FSPath.tempDir.appendingComponent(String.random() + "-\(ProcessInfo.processInfo.processIdentifier)")
    }
    
    deinit {
        try? self.tempLocation.remove()
    }
    
    public func languageForXcode(file: XcodeFileSystemURLResource) -> String? {
        return "xcode.lang.swift"
    }
    
    public func explicitFileTypeForXcode(file: XcodeFileSystemURLResource) -> XcodeFileType? {
        return XcodeFileType.Text.plainText
    }
    
    func isSupportedFile(_ file: String) -> Bool {
        return file.pathExtension.lowercased() == "dswift"
    }
    
    private func getNextLibraryName() -> String {
        let idx = self.commonLibraryCounter.incrementalValue()
        return DynamicSourceCodeGenerator.CommonLibraryName + "\(idx)"
        
    }
    
    public func getNextClassName() -> String {
        let idx = self.commonClassCounter.incrementalValue()
        return DynamicSourceCodeGenerator.CommonClassName + "\(idx)"
    }
    
    private func createModule(sourcePath: FSPath,
                              project: SwiftProject,
                              using fileManager: FileManager) throws -> (moduleName: String,
                                                                         moduleLocation: FSPath,
                                                                         sourceEncoding: String.Encoding,
                                                                         containsDependencies: Bool) {
        guard sourcePath.exists(using: fileManager) else {
            throw Errors.missingSource(atPath: sourcePath.string)
        }
        
        
        let clsName: String = getNextClassName()
        
        let tempLoc = self.tempLocation
        var moduleName: String = getNextLibraryName()
        var projectDestination = tempLoc.appendingComponent(moduleName)
        
        // Keep checking to find a module name that does not exist on the file system
        while projectDestination.exists(using: fileManager) {
            moduleName = getNextLibraryName()
            projectDestination = tempLoc.appendingComponent(moduleName)
        }
    
        
        do {
            try projectDestination.createDirectory(withIntermediateDirectories: true,
                                                   using: fileManager)
        } catch {
            throw Errors.couldNotCreateFolder(.project,
                                              atPath: projectDestination.string,
                                              error)
        }
        
        
        self.console.printVerbose("Created temp project folder \(projectDestination.string)",
                                  object: self)
        
        
        let sourceFolder = projectDestination.appendingComponent("Sources")
        do {
            try sourceFolder.createDirectory(withIntermediateDirectories: true,
                                             using: fileManager)
        } catch {
            throw Errors.couldNotCreateFolder(.sources,
                                              atPath: sourceFolder.string,
                                              error)
            
        }
        
        self.console.printVerbose("Created Sources folder", object: self)
        
        let moduleSourceFolder = sourceFolder.appendingComponent(moduleName)
        do {
            try moduleSourceFolder.createDirectory(withIntermediateDirectories: true,
                                             using: fileManager)
        } catch {
            throw Errors.couldNotCreateFolder(.module,
                                              atPath: sourceFolder.string,
                                              error)
        }
        
        self.console.printVerbose("Created \(moduleName) folder", object: self)
        
        
        let srcBuilderSrc: String!
        let srcBuilderEnc: String.Encoding!
        let includeFolders: [DSwiftTag.Include.Folder]
        let includePackages: [DSwiftTag.Include.GitPackageDependency]
        let containsDependencies: Bool
        do {
            let builder = try DynamicSourceCodeBuilder.init(file: sourcePath,
                                                            swiftProject: project,
                                                            className: clsName,
                                                            dswiftInfo: self.dswiftInfo,
                                                            preloadedDetails: self.preloadedDetails,
                                                            console: self.console,
                                                            using: fileManager)
            self.console.printVerbose("Loaded source generator", object: self)
            srcBuilderSrc = try builder.generateSourceGenerator()
            srcBuilderEnc = builder.sourceEncoding
            includeFolders = builder.includeFolders
            includePackages = builder.includePackages
            containsDependencies = !includePackages.isEmpty
        } catch {
            includeFolders = []
            includePackages = []
            containsDependencies = false
            throw Errors.unableToGenerateSource(for: sourcePath.string, error)
        }
        self.console.printVerbose("Generated source code", object: self)
        
        
        
        var packageSourceCode = """
// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "\(moduleName)",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),

"""
        for (index, package) in includePackages.enumerated() {
            if index > 0 && index < (includePackages.count-1) { packageSourceCode += ",\n" }
            packageSourceCode += "        .package(url: \"\(package.url)\", \(package.requirements.tag))"
        }
        
        packageSourceCode += """

    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package
        // depends on.
        .target(
            name: "\(moduleName)",
            dependencies: [\(includePackages.flatMap({ return $0.packageNames  }).map({ return "\"\($0)\"" }).joined(separator: ", "))])
    ]
)
"""
        let packageFilePath = projectDestination.appendingComponent("Package.swift")
        
        do {
            try packageSourceCode.write(to: packageFilePath,
                                        atomically: false,
                                        encoding: DynamicSourceCodeGenerator.PACKAGE_FILE_ENCODING,
                                        using: fileManager)
        } catch {
            throw Errors.unableToWriteFile(atPath: packageFilePath.string, error)
        }
        
        self.console.printVerbose("Wrote Package.swift file", object: self)
        
        let classFilePath = moduleSourceFolder.appendingComponent("main.swift")
        do {
            try srcBuilderSrc.write(to: classFilePath,
                                    atomically: false,
                                    encoding: srcBuilderEnc,
                                    using: fileManager)
        } catch {
            throw Errors.unableToWriteFile(atPath: classFilePath.string, error)
        }
        self.console.printVerbose("Wrote main.swift", object: self)
        
        for include in includeFolders {
            self.console.printVerbose("Including Folder '\(include.path)'")
            let relPath = include.path
                .replacingOccurrences(of: "../", with: "/")
                .replacingOccurrences(of: "./", with: "")
            
            //let toPath = moduleSourceFolder + relPath
            let toPath = moduleSourceFolder.appendingComponent(relPath.string)
            
            let count = try include.copyFiles(to: toPath,
                                              console: self.console)
            if count == 0 {
                console.print("WARNING: No files copied from '\(include.path)'")
            }
        }
        
        return (moduleName: moduleName,
                moduleLocation: projectDestination,
                sourceEncoding: srcBuilderEnc,
                containsDependencies: containsDependencies)
    }
    
    
    
    private func updateModule(sourcePath: FSPath,
                              moduleLocation: FSPath) throws {
        self.console.printVerbose("Loading external resources", object: self)
        
        let pkgUpdateResponse = try self.swiftCLI.waitAndCaptureStringResponse(arguments: ["package", "update"],
                                                                               currentDirectory: moduleLocation.url,
                                                                               outputOptions: .captureAll)
        
        if pkgUpdateResponse.exitStatusCode != 0 {
            self.console.printVerbose("There was an error while loading external resources", object: self)
            var errStr: String = pkgUpdateResponse.output ?? ""
            
            if let r = errStr.range(of: ": error: ") {
                let idx = errStr.index(r.lowerBound, offsetBy: 2)
                errStr = String(errStr.suffix(from: idx))
            }
            if let r = errStr.range(of: "\nerror: terminated(1):") {
                errStr = String(errStr.prefix(upTo: r.lowerBound))
            }
            throw Errors.buildModuleFailed(for: sourcePath.string,
                                           withCode: Int(pkgUpdateResponse.exitStatusCode),
                                           returingError: errStr)
        }
        
        self.console.printVerbose("Loading external resources completed", object: self)
        
        
    }
    
    private func buildModule(sourcePath: FSPath,
                             moduleLocation: FSPath) throws -> FSPath {
        self.console.printVerbose("Compiling generator", object: self)
        
        let buildResponse = try self.swiftCLI.waitAndCaptureStringResponse(arguments: ["build"],
                                                                           currentDirectory: moduleLocation.url,
                                                                           outputOptions: .captureAll)
        
        if buildResponse.exitStatusCode != 0 {
            self.console.printVerbose("There was an error while generating source", object: self)
            var errStr: String = buildResponse.output ?? ""
            
            if let r = errStr.range(of: ": error: ") {
                let idx = errStr.index(r.lowerBound, offsetBy: 2)
                errStr = String(errStr.suffix(from: idx))
            }
            if let r = errStr.range(of: "\nerror: terminated(1):") {
                errStr = String(errStr.prefix(upTo: r.lowerBound))
            }
            throw Errors.buildModuleFailed(for: sourcePath.string,
                                           withCode: Int(buildResponse.exitStatusCode),
                                           returingError: errStr)
        }
        
        let buildPathResponse = try self.swiftCLI.waitAndCaptureStringResponse(arguments: ["build", "--show-bin-path"],
                                                                           currentDirectory: moduleLocation.url,
                                                                           outputOptions: .captureAll)
        
        
        self.console.printVerbose("Compiling completed", object: self)
        
        guard var modulePathStr = buildPathResponse.output else {
            throw Errors.unableToReadSTDOut
        }
        
        let modulePathLines = modulePathStr.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n").map(String.init)
        modulePathStr = modulePathLines[modulePathLines.count - 1]
        
        return FSPath(modulePathStr)
        
    }
    
    private func runModule(atPath path: FSPath,
                           module: String,
                           havingOutputEncoding encoding: String.Encoding,
                           using fileManager: FileManager) throws -> String {
        self.console.printVerbose("Running module generator \(path)", object: self)
        
        let workingFolder = path.deletingLastComponent()
        let outputFile = workingFolder.appendingComponent("swift.out")
        defer { try? outputFile.remove(using: fileManager) }
        
        let runResponse = try self.swiftCLI.waitAndCaptureStringResponse(arguments: [
                                                                            "run",
                                                                             module,
                                                                             outputFile.string
                                                                         ],
                                                                         currentDirectory: workingFolder.url,
                                                                         outputOptions: .captureAll)
        
        
        if runResponse.exitStatusCode != 0 {
            self.console.printVerbose("There was an error while running module source generator", object: self)
            let errStr: String = runResponse.output ?? ""
            
            throw Errors.runModuleFailed(for: path.string,
                                         withCode: Int(runResponse.exitStatusCode),
                                         returingError: errStr)
        }
        
        self.console.printVerbose("Running module completed", object: self)
        
        return try String(contentsOf: outputFile,
                          encoding: encoding,
                          using: fileManager)
    }
    
    public func generateSource(from sourcePath: FSPath,
                               project: SwiftProject,
                               using fileManager: FileManager) throws -> (source: String, encoding: String.Encoding) {
        
        self.console.printVerbose("Creating module for '\(sourcePath.lastComponent)'", object: self)
        let mod = try createModule(sourcePath: sourcePath,
                                   project: project,
                                   using: fileManager)
        defer { try? mod.moduleLocation.remove(using: fileManager) }
        
        if mod.containsDependencies {
            // Try calling swift package update to download any dependencies
            try self.updateModule(sourcePath: sourcePath,
                                  moduleLocation: mod.moduleLocation)
        }
        
        self.console.printVerbose("Building module for '\(sourcePath.lastComponent)'",
                                  object: self)
        let modulePath = try self.buildModule(sourcePath: sourcePath,
                                              moduleLocation: mod.moduleLocation)
        
        self.console.printVerbose("Running module for '\(sourcePath.lastComponent)'", object: self)
        let src = try self.runModule(atPath: modulePath.appendingComponent(mod.moduleName),
                                     module: mod.moduleName,
                                     havingOutputEncoding: mod.sourceEncoding,
                                     using: fileManager)
        return (source: src, encoding: mod.sourceEncoding)
        
    }
    
    
    
    public func generateSource(from sourcePath: FSPath,
                               to destinationPath: FSPath,
                               project: SwiftProject,
                               lockGenFiles: Bool,
                               using fileManager: FileManager) throws {
        self.console.printVerbose("Generating source for '\(sourcePath)'", object: self)
        let s = try self.generateSource(from: sourcePath,
                                        project: project,
                                        using: fileManager)
        guard  destinationPath.exists(using: fileManager) else {
            try s.source.write(to: destinationPath,
                               atomically: false,
                               encoding: s.encoding,
                               using: fileManager)
            if lockGenFiles {
                do {
                    //marking generated file as read-only
                    try destinationPath.setPosixPermissions(0444,
                                                            using: fileManager)
                } catch {
                    self.console.printVerbose("Unable to mark'\(destinationPath)' as readonly",
                                            object: self)
                }
            }
            return
        }
        
        
        var enc: String.Encoding = project.xcodeFile(at: sourcePath)?.encoding ?? .utf8
        let oldSource = try String(contentsOf: destinationPath,
                                   foundEncoding: &enc,
                                   using: fileManager)
        // Try and compare new source with old source.  Only update if they are not the same
        // We do this so that the file modification does not happen unless absolutely required
        // so git does not think its a new file unless it really is
        //guard s.source != oldSource else {
        guard !self.compareSources(s.source, oldSource) else {
            self.console.printVerbose("No changes to source: \(destinationPath)",
                                    object: self)
            return
        }
       
        do {
            try destinationPath.remove(using: fileManager)
        } catch {
            self.console.printVerbose("Unable to remove old version of '\(destinationPath)'",
                                    object: self)
        }
        try s.source.write(to: destinationPath,
                           atomically: false,
                           encoding: s.encoding,
                           using: fileManager)
        if lockGenFiles {
            do {
                //marking generated file as read-only
                try destinationPath.setPosixPermissions(0444,
                                                        using: fileManager)
            } catch {
                self.console.printVerbose("Unable to mark'\(destinationPath)' as readonly",
                                        object: self)
            }
        }
    }
    
    private func compareSources(_ src1: String, _ src2: String) -> Bool {
        var lhs = src1
        var rhs = src2
        // reduce os specific lines to same type (change windows to linux/unix)
        lhs = lhs.replacingOccurrences(of: "\r\n", with: "\n")
        // reduce os specific lines to same type (change windows to linux/unix)
        rhs = rhs.replacingOccurrences(of: "\r\n", with: "\n")
        
        let endOfTopCommentIdentifiers = DynamicSourceCodeBuilder.generateListOfEndOfDSwiftTopCommentBlock(dswiftInfo: dswiftInfo)
        var hasFixedSrc1: Bool = false
        var hasFixedSrc2: Bool = false
        for ident in endOfTopCommentIdentifiers {
            if !hasFixedSrc1,
               let r = lhs.range(of: ident) {
                // remove everything from the top of the string upto and including
                // the last line of the stop dswift comment block
                lhs = String(lhs[r.upperBound...])
                hasFixedSrc1 = true
            }
            if !hasFixedSrc2,
               let r = rhs.range(of: ident) {
                // remove everything from the top of the string upto and including
                // the last line of the stop dswift comment block
                rhs = String(rhs[r.upperBound...])
                hasFixedSrc2 = true
            }
            if hasFixedSrc1 && hasFixedSrc2 {
                break
            }
        }
        
        return lhs == rhs
    }
    
    // Check to see if any of the included files have been modified since the
    // destination has been genreated
    private func isGenerationOutOfSyncWithReferences(generationDate: Date,
                                                     source: FSPath,
                                                     project: SwiftProject,
                                                     using fileManager: FileManager/* = .default*/) throws -> Bool {
        
        
        
        let tags = try self.preloadedDetails.getDSwiftTags(in: source,
                                                           encoding: nil,
                                                           project: project,
                                                           console: self.console,
                                                           using: fileManager)
        
        for tag in tags {
            if try tag.hasBeenModified(since: generationDate,
                                       using: fileManager,
                                       console: console) {
                return true
            }
        }
        
        return false
        
    }
    
    public func requiresSourceCodeGeneration(for source: FSPath,
                                             project: SwiftProject,
                                             using fileManager: FileManager /* = .default */) throws -> Bool {
        
        let destination = try generatedFilePath(for: source, using: fileManager)
        
        // If the generated file does not exist, then return true
        guard destination.exists(using: fileManager) else {
            self.console.printVerbose("Generated file '\(destination)' does not exists",
                                    object: self)
            return true
        }
        // Get the modification dates otherwise return true to rebuild
        guard let srcMod = source.safely.modificationDate(using: fileManager),
              let desMod = destination.safely.modificationDate(using: fileManager) else {
                  self.console.printVerbose("Wasn't able to get all modification dates",
                                          object: self)
            return true
        }
        
        // Source or static file is newer than destination, meaning we must rebuild
        guard srcMod <= desMod else {
            self.console.printVerbose("'\(source)' is newer",
                                    object: self)
            return true
        }
        
        guard !(try self.checkForFailedGenerationCommentInDestination(for: source,
                                                                      destination: destination,
                                                                         using: fileManager)) else {
            return true
        }
        
        self.console.printVerbose("Checking for modified includes within '\(source)'",
                                object: self)
        // Check to see if any of the included files have been modified since the
        // destination has been genreated
        let outOfSync = try self.isGenerationOutOfSyncWithReferences(generationDate: desMod,
                                                                    //originalSource: source.path,
                                                                    source: source,
                                                                     project: project,
                                                                     using: fileManager)
        guard !outOfSync else {
            return true
        }
        
        return false
        
    }
    
    
    public func updateXcodeProject(xcodeFile: XcodeFileSystemURLResource,
                                   inGroup group: XcodeGroup,
                                   havingTarget target: XcodeTarget,
                                   includeGeneratedFilesInXcodeProject: Bool,
                                   using fileManager: FileManager) throws -> Bool {
        var rtn: Bool = false

        if group.file(atPath: xcodeFile.lastPathComponent) == nil {
            // Only add the dswift file to the project if its not already there
            self.console.printVerbose("Trying to add file \(xcodeFile.path) to Xcode in group '\(group.path!)'",
                                    object: self)
            let f = try group.addExisting(xcodeFile,
                                          copyLocally: true,
                                          savePBXFile: false) as! XcodeFile
            self.console.printVerbose("Added file \(xcodeFile.path) to Xcode",
                                    object: self)
            
            //f.languageSpecificationIdentifier = "xcode.lang.swift"
            f.languageSpecificationIdentifier = self.languageForXcode(file: xcodeFile)
            f.explicitFileType = self.explicitFileTypeForXcode(file: xcodeFile)
            target.sourcesBuildPhase().createBuildFile(for: f)
            //print("Adding dswift file '\(child.path)'")
            rtn = true
        }
       
            
        
        let swiftName = try self.generatedFilePath(for: xcodeFile).lastComponent
        if let f = group.file(atPath: swiftName) {
            
            //let source = try String(contentsOf: URL(fileURLWithPath: f.fullPath), encoding: f.encoding ?? .utf8)
            let source: String = try {
                if let e = f.encoding {
                    return try String(contentsOf: URL(fileURLWithPath: f.fullPath),
                                      encoding: e)
                } else {
                    var srcEnc: String.Encoding = .utf8
                    return try String(contentsOf: URL(fileURLWithPath: f.fullPath),
                                      foundEncoding: &srcEnc)
                }
            }()
            // Make sure we are working with a generated file
            if source.hasPrefix("//  This file was dynamically generated from") {
                if !includeGeneratedFilesInXcodeProject {
                    try f.remove(deletingFiles: false, savePBXFile: false)
                } else {
                    // Remove target membership for file
                    target.remove(file: f, from: .sourceBuildPhase)
                }
                rtn = true
            }
        }
        
        return rtn
    }
}
