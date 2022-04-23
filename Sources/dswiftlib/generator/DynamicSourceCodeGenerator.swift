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


public class DynamicSourceCodeGenerator: DynamicGenerator {
    
    public class TagReplacementDetails {
        
        public class IncludeReplacement {
            private var raw: [String: Any] = [:]
            private let lock = NSLock()
            
            public subscript(_ key: String) -> Any? {
                get {
                    self.lock.lock()
                    defer { self.lock.unlock() }
                    return self.raw[key]
                }
                set {
                    self.lock.lock()
                    defer { self.lock.unlock() }
                    self.raw[key] = newValue
                }
            }
            
            public subscript<T>(_ key: String, ofType type: T.Type) -> T? {
                get {
                    self.lock.lock()
                    defer { self.lock.unlock() }
                    return self.raw[key] as? T
                }
            }
            
            public var processedIncludeFiles: [String] {
                get { return self["included.files.processed", ofType: [String].self] ?? [] }
                set { self["included.files.processed"] = newValue }
            }
        }
        private var raw: [String: Any] = [:]
        private let lock = NSLock()
        
        public subscript(_ key: String) -> Any? {
            get {
                self.lock.lock()
                defer { self.lock.unlock() }
                return self.raw[key]
            }
            set {
                self.lock.lock()
                defer { self.lock.unlock() }
                self.raw[key] = newValue
            }
        }
        
        public subscript<T>(_ key: String, ofType type: T.Type) -> T? {
            get {
                self.lock.lock()
                defer { self.lock.unlock() }
                return self.raw[key] as? T
            }
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
        
        public typealias DSWIFT_TOOLS_VERSION_PARSER = (_ path: String,
                                                        _ source: String,
                                                        _ console: Console) throws -> Version.SingleVersion?
        
        public typealias DSWIFT_TAGS_PARSER = (_ path: String,
                                               _ source: String,
                                               _ project: SwiftProject,
                                               _ console:  Console) throws -> [DSwiftTag]
        
        private var sourceContent: [String: (content: String, encoding: String.Encoding)]
        private let sourceContentLock = NSLock()
        
        
        
        private var sourceVersion: [String: Version.SingleVersion?]
        private let sourceVersionLock = NSLock()
        private let parseDSwiftToolsVersion: DSWIFT_TOOLS_VERSION_PARSER
        
        private var dswiftTags: [String: [DSwiftTag]]
        private let dswiftTagsLock = NSLock()
        private let parseDSwiftTags: DSWIFT_TAGS_PARSER
        
        //private let project: SwiftProject
        
        
        
        public init(//project: SwiftProject,
                    sourceContent: [String: (content: String, encoding: String.Encoding)] = [:],
                    sourceVersion: [String: Version.SingleVersion?] = [:],
                    parseDSwiftToolsVersion: @escaping DSWIFT_TOOLS_VERSION_PARSER,
                    dswiftTags: [String: [DSwiftTag]] = [:],
                    parseDSwiftTags: @escaping DSWIFT_TAGS_PARSER) {
            //self.project = project
            self.sourceContent = sourceContent
            self.sourceVersion = sourceVersion
            self.parseDSwiftToolsVersion = parseDSwiftToolsVersion
            self.dswiftTags = dswiftTags
            self.parseDSwiftTags = parseDSwiftTags
        }
        
        public func getSourceContent(for path: String,
                                     encoding: String.Encoding?,// = nil,
                                     console: Console = .null) throws -> (content: String, encoding: String.Encoding) {
            self.sourceContentLock.lock()
            defer { self.sourceContentLock.unlock() }
            if let rtn = self.sourceContent[path] { return rtn }
            
            if let enc = encoding /*?? self.project.file(atPath: path)?.encoding*/ {
                console.printVerbose("Reading file '\(path.lastPathComponent)' with encoding \(enc)", object: self)
                let includeSrc = try String(contentsOfFile: path, encoding: enc)
                self.sourceContent[path] =  (content: includeSrc, encoding: enc)
                return (content: includeSrc, encoding: enc)
            } else {
                console.printVerbose("Reading file '\(path.lastPathComponent)'", object: self)
                var enc: String.Encoding = .utf8
                let includeSrc = try String(contentsOfFile: path, foundEncoding: &enc)
                
                self.sourceContent[path] =  (content: includeSrc, encoding: enc)
                return (content: includeSrc, encoding: enc)
            }
        }
        
        public func getSourceContent(for path: String,
                                     project: SwiftProject,
                                     console: Console = .null) throws -> (content: String, encoding: String.Encoding) {
            return try self.getSourceContent(for: path,
                                                encoding: project.xcodeFile(atPath: path)?.encoding,
                                                console: console)
        }
        
        
        
        public func getSourceDSwiftVersion(for path: String,
                                           source: String,
                                           console: Console = .null) throws -> Version.SingleVersion? {
            
            self.sourceVersionLock.lock()
            defer { self.sourceVersionLock.unlock() }
            
            if let ver = self.sourceVersion[path] { return ver }
            
            let ver = try self.parseDSwiftToolsVersion(path, source, console)
            
            self.sourceVersion[path] = ver
            
            return ver
            
        }
        
        public func getSourceDSwiftVersion(for path: String,
                                           encoding: String.Encoding?,// = nil,
                                           console: Console = .null) throws -> Version.SingleVersion? {
            
            self.sourceVersionLock.lock()
            defer { self.sourceVersionLock.unlock() }
            
            if let ver = self.sourceVersion[path] { return ver }
            
            let source = (try self.getSourceContent(for: path,
                                                    encoding: encoding,
                                                    console: console)).content
            
            let ver = try self.parseDSwiftToolsVersion(path, source, console)
            
            self.sourceVersion[path] = ver
            
            return ver
            
            
        }
        
        public func getSourceDSwiftVersion(for path: String,
                                           project: SwiftProject,
                                           console: Console = .null) throws -> Version.SingleVersion? {
            return try self.getSourceDSwiftVersion(for: path,
                                                   encoding: project.xcodeFile(atPath: path)?.encoding,
                                                   console: console)
        }
        public func getDSwiftTags(in path: String,
                                  source: String,
                                  project: SwiftProject,
                                  console: Console = .null) throws -> [DSwiftTag] {
            self.dswiftTagsLock.lock()
            defer { self.dswiftTagsLock.unlock() }
            if let rtn = self.dswiftTags[path] { return rtn }
            
            let rtn = try self.parseDSwiftTags(path, source, project, console)
            self.dswiftTags[path] = rtn
            return rtn
        }
        
        public func getDSwiftTags(in path: String,
                                  encoding: String.Encoding?,// = nil,
                                  project: SwiftProject,
                                  console: Console = .null) throws -> [DSwiftTag] {
            self.dswiftTagsLock.lock()
            defer { self.dswiftTagsLock.unlock() }
            if let rtn = self.dswiftTags[path] { return rtn }
            
            let content = (try self.getSourceContent(for: path,
                                                     encoding: encoding,
                                                     console: console)).content
            
            let rtn = try self.parseDSwiftTags(path,
                                               content,
                                               project,
                                               console)
            self.dswiftTags[path] = rtn
            return rtn
        }
        
        public func getDSwiftTags(in path: String,
                                  project: SwiftProject,
                                  console: Console = .null) throws -> [DSwiftTag] {
            return try self.getDSwiftTags(in: path,
                                          encoding: project.xcodeFile(atPath: path)?.encoding,
                                          project: project,
                                          console: console)
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
    
    public var supportedExtensions: [String] { return ["dswift"] }
    
    /*#if os(Linux)
    private static let MANGLED_INIT_PREFIX: String = "_T0"
    #else
    private static let MANGLED_INIT_PREFIX: String = "_$S"
    #endif
    private static let MANGLED_INIT_SUFFIX: String = "CACycfC"*/
    
    private static let CommonLibraryName: String = "LibraryGen"
    private let commonLibraryCounter = SyncLockObj<Int>(value: 0)
    
    private static let CommonClassName: String = "ClassGEN"
    private let commonClassCounter = SyncLockObj<Int>(value: 0)
    
    private let tempLocation: URL = {
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(String.random() + "-\(ProcessInfo.processInfo.processIdentifier)")
        
    } ()
    
    private let swiftCLI: CLICapture
    
    public let dswiftInfo: DSwiftInfo
    public let console: Console
    
    internal var preloadedDetails: PreloadedDetails
    
    required public init(swiftCLI: CLICapture,
                         dswiftInfo: DSwiftInfo,
                         console: Console = .null) throws {
        self.swiftCLI = swiftCLI
        
        self.dswiftInfo = dswiftInfo
        self.preloadedDetails = PreloadedDetails(parseDSwiftToolsVersion: DynamicSourceCodeBuilder.parseDSwiftToolsVersion(from:source:console:),
                                                 parseDSwiftTags: DynamicSourceCodeBuilder.parseDSwiftTags(in:source:project:console:))
        self.console = console
    }
    
    deinit {
        try? FileManager.default.removeItem(at: tempLocation)
    }
    
    public func languageForXcode(file: String) -> String? {
        return "xcode.lang.swift"
    }
    
    public func explicitFileTypeForXcode(file: String) -> XcodeFileType? {
        return XcodeFileType.Text.plainText
    }
    
    func isSupportedFile(_ file: String) -> Bool {
        return file.pathExtension.lowercased() == "dswift"
    }
    
    private func getNextLibraryName() -> String {
        /*let idx: Int = commonLibraryLock.sync {
            let rtn = commonLibraryCounter
            commonLibraryCounter += 1
            return rtn
        }*/
        let idx = self.commonLibraryCounter.incrementalValue()
        //self.console.print("Using Library Name '\(DynamicSourceCodeGenerator.CommonLibraryName)\(idx)'")
        return DynamicSourceCodeGenerator.CommonLibraryName + "\(idx)"
        
    }
    
    public func getNextClassName() -> String {
        /*let idx: Int = commonClassLock.sync {
            let rtn = commonClassCounter
            commonClassCounter += 1
            return rtn
        }*/
        let idx = self.commonClassCounter.incrementalValue()
        return DynamicSourceCodeGenerator.CommonClassName + "\(idx)"
    }
    
    private func createModule(sourcePath: String,
                              project: SwiftProject) throws -> (moduleName: String, moduleLocation: URL, sourceEncoding: String.Encoding, containsDependencies: Bool) {
        if !FileManager.default.fileExists(atPath: sourcePath) {
            throw Errors.missingSource(atPath: sourcePath)
        }
        
        
        let clsName: String = getNextClassName()
        
        var moduleName: String = getNextLibraryName()
        var projectDestination = tempLocation.appendingPathComponent(moduleName)
        
        // Keep checking to find a module name that does not exist on the file system
        while FileManager.default.fileExists(atPath: projectDestination.path) {
            moduleName = getNextLibraryName()
            projectDestination = tempLocation.appendingPathComponent(moduleName)
        }
    
        
        do {
            try FileManager.default.createDirectory(at: projectDestination,
                                                    withIntermediateDirectories: true)
        } catch {
            throw Errors.couldNotCreateFolder(.project, atPath: projectDestination.path, error)
        }
        
        
        self.console.printVerbose("Created temp project folder \(projectDestination.path)", object: self)
        
        
        let sourceFolder = projectDestination.appendingPathComponent("Sources")
        do {
            try FileManager.default.createDirectory(at: sourceFolder,
                                                    withIntermediateDirectories: false)
        } catch {
            throw Errors.couldNotCreateFolder(.sources, atPath: sourceFolder.path, error)
            
        }
        
        self.console.printVerbose("Created Sources folder", object: self)
        
        let moduleSourceFolder = sourceFolder.appendingPathComponent(moduleName)
        do {
            try FileManager.default.createDirectory(at: moduleSourceFolder,
                                                    withIntermediateDirectories: false)
        } catch {
            throw Errors.couldNotCreateFolder(.module, atPath: sourceFolder.path, error)
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
                                                            console: self.console)
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
            throw Errors.unableToGenerateSource(for: sourcePath, error)
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
            packageSourceCode += "        .package(url: \"\(package.url)\", from: \"\(package.from)\")"
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
        let packageFileName = projectDestination.appendingPathComponent("Package.swift",
                                                                        isDirectory: false)
        
        do {
            try packageSourceCode.write(to: packageFileName,
                                        atomically: false,
                                        encoding: DynamicSourceCodeGenerator.PACKAGE_FILE_ENCODING)
        } catch {
            throw Errors.unableToWriteFile(atPath: packageFileName.path, error)
        }
        
        self.console.printVerbose("Wrote Package.swift file", object: self)
        
        let classFileName = moduleSourceFolder.appendingPathComponent("main.swift", isDirectory: false)
        do {
            try srcBuilderSrc.write(to: classFileName, atomically: false, encoding: srcBuilderEnc)
        } catch {
            throw Errors.unableToWriteFile(atPath: classFileName.path, error)
        }
        self.console.printVerbose("Wrote main.swift", object: self)
        
        for include in includeFolders {
            self.console.printVerbose("Including Folder '\(include.path)'")
            let relPath = include.path
                .replacingOccurrences(of: "../", with: "/")
                .replacingOccurrences(of: "./", with: "")
            
            let toPath = moduleSourceFolder.appendingPathComponent(relPath)
            
            try include.copyFiles(to: toPath.path,
                                  console: self.console)
        }
        
        return (moduleName: moduleName,
                moduleLocation: projectDestination,
                sourceEncoding: srcBuilderEnc,
                containsDependencies: containsDependencies)
    }
    
    
    
    private func updateModule(sourcePath: String, moduleLocation: URL) throws {
        self.console.printVerbose("Loading external resources", object: self)
        
        let pkgUpdateResponse = try self.swiftCLI.waitAndCaptureStringResponse(arguments: ["package", "update"],
                                                                               currentDirectory: URL(fileURLWithPath: moduleLocation.path),
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
            throw Errors.buildModuleFailed(for: sourcePath,
                                           withCode: Int(pkgUpdateResponse.exitStatusCode),
                                           returingError: errStr)
        }
        
        self.console.printVerbose("Loading external resources completed", object: self)
        
        
    }
    
    private func buildModule(sourcePath: String, moduleLocation: URL) throws -> String {
        self.console.printVerbose("Compiling generator", object: self)
        
        let buildResponse = try self.swiftCLI.waitAndCaptureStringResponse(arguments: ["build"],
                                                                           currentDirectory: URL(fileURLWithPath: moduleLocation.path),
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
            throw Errors.buildModuleFailed(for: sourcePath,
                                           withCode: Int(buildResponse.exitStatusCode),
                                           returingError: errStr)
        }
        
        let buildPathResponse = try self.swiftCLI.waitAndCaptureStringResponse(arguments: ["build", "--show-bin-path"],
                                                                           currentDirectory: URL(fileURLWithPath: moduleLocation.path),
                                                                           outputOptions: .captureAll)
        
        
        self.console.printVerbose("Compiling completed", object: self)
        
        guard var modulePathStr = buildPathResponse.output else {
            throw Errors.unableToReadSTDOut
        }
        
        let modulePathLines = modulePathStr.split(separator: "\n").map(String.init)
        modulePathStr = modulePathLines[modulePathLines.count - 1]
        
        return modulePathStr
        
    }
    
    private func runModule(atPath path: String, havingOutputEncoding encoding: String.Encoding) throws -> String {
        self.console.printVerbose("Running module generator \(path)", object: self)
        
        let workingFolder: String = path.deletingLastPathComponent
        let outputFile: String = workingFolder + "/" + "swift.out"
        defer { try? FileManager.default.removeItem(atPath: outputFile) }
        
        let cli = CLICapture(executable: URL(fileURLWithPath: path))
        
        let runResponse = try cli.waitAndCaptureStringResponse(arguments: [outputFile],
                                                               currentDirectory: URL(fileURLWithPath: workingFolder),
                                                               outputOptions: .captureAll)
        
        
        if runResponse.exitStatusCode != 0 {
            self.console.printVerbose("There was an error while running module source generator", object: self)
            let errStr: String = runResponse.output ?? ""
            
            throw Errors.runModuleFailed(for: path,
                                         withCode: Int(runResponse.exitStatusCode),
                                         returingError: errStr)
        }
        
        self.console.printVerbose("Running module completed", object: self)
        
        return try String(contentsOf: URL(fileURLWithPath: outputFile),
                          encoding: encoding)
    }
    
    public func generateSource(from sourcePath: String,
                               project: SwiftProject) throws -> (source: String, encoding: String.Encoding) {
        
        self.console.printVerbose("Creating module for '\(sourcePath.lastPathComponent)'", object: self)
        let mod = try createModule(sourcePath: sourcePath,
                                   project: project)
        defer { try? FileManager.default.removeItem(at: mod.moduleLocation) }
        
        if mod.containsDependencies {
            // Try calling swift package update to download any dependencies
            try self.updateModule(sourcePath: sourcePath,
                                  moduleLocation: mod.moduleLocation)
        }
        
        self.console.printVerbose("Building module for '\(sourcePath.lastPathComponent)'", object: self)
        var modulePathStr: String = try self.buildModule(sourcePath: sourcePath,
                                                         moduleLocation: mod.moduleLocation)
        modulePathStr += "/" + mod.moduleName
        
        self.console.printVerbose("Running module for '\(sourcePath.lastPathComponent)'", object: self)
        let src = try self.runModule(atPath: modulePathStr,
                                     havingOutputEncoding: mod.sourceEncoding)
        return (source: src, encoding: mod.sourceEncoding)
        
    }
    
    
    
    public func generateSource(from sourcePath: String,
                               to destinationPath: String,
                               project: SwiftProject,
                               lockGenFiles: Bool) throws {
        self.console.printVerbose("Generating source for '\(sourcePath)'", object: self)
        let s = try self.generateSource(from: sourcePath,
                                        project: project)
        guard  FileManager.default.fileExists(atPath: destinationPath) else {
            try s.source.write(toFile: destinationPath,
                               atomically: false,
                               encoding: s.encoding)
            if lockGenFiles {
                do {
                    //marking generated file as read-only
                    try FileManager.default.setPosixPermissions(0444,
                                                                ofItemAtPath: destinationPath)
                } catch {
                    self.console.printVerbose("Unable to mark'\(destinationPath)' as readonly",
                                            object: self)
                }
            }
            return
        }
        
        
        var enc: String.Encoding = project.xcodeFile(atPath: sourcePath)?.encoding ?? .utf8
        let oldSource = try String(contentsOfFile: destinationPath, foundEncoding: &enc)
        // Try and compare new source with old source.  Only update if they are not the same
        // We do this so that the file modification does not happen unless absolutely required
        // so git does not think its a new file unless it really is
        guard s.source != oldSource else {
            self.console.printVerbose("No changes to source: \(destinationPath)",
                                    object: self)
            return
        }
       
        do {
            try FileManager.default.removeItem(atPath: destinationPath)
        } catch {
            self.console.printVerbose("Unable to remove old version of '\(destinationPath)'",
                                    object: self)
        }
        try s.source.write(toFile: destinationPath,
                           atomically: false,
                           encoding: s.encoding)
        if lockGenFiles {
            do {
                //marking generated file as read-only
                try FileManager.default.setPosixPermissions(0444,
                                                            ofItemAtPath: destinationPath)
            } catch {
                self.console.printVerbose("Unable to mark'\(destinationPath)' as readonly",
                                        object: self)
            }
        }
    }
    
    // Check to see if any of the included files have been modified since the
    // destination has been genreated
    private func isGenerationOutOfSyncWithReferences(generationDate: Date,
                                                     originalSource: String,
                                                     source: URL,
                                                     project: SwiftProject,
                                                     fileManager: FileManager/* = .default*/) throws -> Bool {
        
        
        
        let tags = try self.preloadedDetails.getDSwiftTags(in: source.path,
                                                           encoding: nil,
                                                           project: project,
                                                           console: self.console)
        
        for tag in tags {
            if try tag.hasBeenModified(since: generationDate,
                                       fileManager: fileManager,
                                       console: console) {
                return true
            }
        }
        
        return false
        
    }
    
    public func requiresSourceCodeGeneration(for source: URL,
                                             project: SwiftProject,
                                             fileManager: FileManager /* = .default */) throws -> Bool {
        let destination = try generatedFilePath(for: source)
        
        // If the generated file does not exist, then return true
        guard fileManager.fileExists(atPath: destination.path) else {
            self.console.printVerbose("Generated file '\(destination.path)' does not exists",
                                    object: self)
            return true
        }
        // Get the modification dates otherwise return true to rebuild
        guard let srcMod = source.fsSafePath?.modificationDate(),
              let desMod = destination.fsSafePath?.modificationDate() else {
                  self.console.printVerbose("Wasn't able to get all modification dates",
                                          object: self)
            return true
        }
        
        // Source or static file is newer than destination, meaning we must rebuild
        guard srcMod <= desMod else {
            self.console.printVerbose("'\(source.path)' is newer",
                                    object: self)
            return true
        }
        
        guard !(try self.checkForFailedGenerationCommentInDestination(for: source,
                                                                      destination: destination)) else {
            return true
        }
        
        self.console.printVerbose("Checking for modified includes within '\(source.path)'",
                                object: self)
        // Check to see if any of the included files have been modified since the
        // destination has been genreated
        let outOfSync = try self.isGenerationOutOfSyncWithReferences(generationDate: desMod,
                                                                    originalSource: source.path,
                                                                    source: source,
                                                                     project: project,
                                                                     fileManager: fileManager)
        guard !outOfSync else {
            return true
        }
        
        return false
        
    }
    
    
    public func updateXcodeProject(xcodeFile: XcodeFileSystemURLResource,
                                   inGroup group: XcodeGroup,
                                   havingTarget target: XcodeTarget,
                                   includeGeneratedFilesInXcodeProject: Bool) throws -> Bool {
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
            f.languageSpecificationIdentifier = self.languageForXcode(file: xcodeFile.path)
            f.explicitFileType = self.explicitFileTypeForXcode(file: xcodeFile.path)
            target.sourcesBuildPhase().createBuildFile(for: f)
            //print("Adding dswift file '\(child.path)'")
            rtn = true
        }
       
            
        
        let swiftName = try self.generatedFilePath(for: xcodeFile.path).lastPathComponent
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
