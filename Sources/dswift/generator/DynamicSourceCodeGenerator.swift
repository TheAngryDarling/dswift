//
//  DynamicSourceCodeGenerator.swift
//  dswift
//
//  Created by Tyler Anger on 2018-12-04.
//

import Foundation
#if os(Linux)
import Dispatch
import Glibc
#endif
import SwiftPatches
import XcodeProj


public class DynamicSourceCodeGenerator: DynamicGenerator {
    
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
    private var commonLibraryCounter: Int = 0
    private let commonLibraryLock: DispatchQueue = DispatchQueue(label: "LibraryCounterLock")
    
    private static let CommonClassName: String = "ClassGEN"
    private var commonClassCounter: Int = 0
    private let commonClassLock: DispatchQueue = DispatchQueue(label: "ClassCounterLock")
    
    private let tempLocation: URL = { return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(String.random(), isDirectory: true) } ()
    
    private let swiftPath: String
    
    private let _print: PRINT_SIG
    private let _verbosePrint: PRINT_SIG
    private let _debugPrint: PRINT_SIG
    
    private let dSwiftModuleName: String
    private let dSwiftURL: String
    
    required public init(_ swiftPath: String,
                         _ dSwiftModuleName: String,
                         _ dSwiftURL: String,
                         _ print: @escaping PRINT_SIG,
                         _ verbosePrint: @escaping PRINT_SIG,
                         _ debugPrint: @escaping PRINT_SIG) throws {
        if swiftPath.isEmpty { throw Errors.swiftPathNotProvided }
        else if !FileManager.default.fileExists(atPath: swiftPath) { throw Errors.missingSwift(atPath: swiftPath) }
        self.swiftPath = swiftPath
        
        self._print = print
        self._verbosePrint = verbosePrint
        self._debugPrint = debugPrint
        
        self.dSwiftModuleName = dSwiftModuleName
        self.dSwiftURL = dSwiftURL
    }
    
    deinit {
        try? FileManager.default.removeItem(at: tempLocation)
    }
    
    internal func print(_ items: Any...,
                        separator: String = " ",
                        terminator: String = "\n",
                        filename: String = #file,
                        line: Int = #line,
                        funcname: String = #function) {
        let msg: String  = items.reduce("") {
            var rtn: String = $0
            if !rtn.isEmpty { rtn += separator }
            rtn += "\($1)"
            return rtn
        }
        self._print(msg + terminator, filename, line, funcname)
    }
    
    internal func verbosePrint(_ items: Any...,
                               separator: String = " ",
                               terminator: String = "\n",
                               filename: String = #file,
                               line: Int = #line,
                               funcname: String = #function) {
        let msg: String  = items.reduce("") {
            var rtn: String = $0
            if !rtn.isEmpty { rtn += separator }
            rtn += "\($1)"
            return rtn
        }
        self._verbosePrint(msg + terminator, filename, line, funcname)
    }
    
    internal func debugPrint(_ items: Any...,
                             separator: String = " ",
                             terminator: String = "\n",
                             filename: String = #file,
                             line: Int = #line,
                             funcname: String = #function) {
        let msg: String  = items.reduce("") {
            var rtn: String = $0
            if !rtn.isEmpty { rtn += separator }
            rtn += "\($1)"
            return rtn
        }
        self._debugPrint(msg + terminator, filename, line, funcname)
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
        let idx: Int = commonLibraryLock.sync {
            let rtn = commonLibraryCounter
            commonLibraryCounter += 1
            return rtn
        }
        return DynamicSourceCodeGenerator.CommonLibraryName + "\(idx)"
        
    }
    
    private func getNextClassName() -> String {
        let idx: Int = commonClassLock.sync {
            let rtn = commonClassCounter
            commonClassCounter += 1
            return rtn
        }
        return DynamicSourceCodeGenerator.CommonClassName + "\(idx)"
    }
    
    /*private func buildMangledInitSymble(libraryName: String, className: String) -> String {
        var rtn: String = DynamicSourceCodeGenerator.MANGLED_INIT_PREFIX
        rtn += "\(libraryName.count)" + libraryName
        rtn += "\(className.count)" + className
        rtn += DynamicSourceCodeGenerator.MANGLED_INIT_SUFFIX
        return rtn
    }*/
    
    private func which(_ cmd: String) -> String? {
        
        guard let envStr = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        
        let paths = envStr.split(separator: ":").map({String($0)})
        for p in paths {
            var cmdPath: String = p
            if !cmdPath.hasSuffix("/") { cmdPath += "/" }
            cmdPath += cmd
            if FileManager.default.fileExists(atPath: cmdPath) {
                return cmdPath
            }
        }
        return nil
    }
    
    private func createModule(sourcePath: String,
                              havingEncoding encoding: String.Encoding? = nil) throws -> (moduleName: String, moduleLocation: URL, sourceEncoding: String.Encoding) {
        if !FileManager.default.fileExists(atPath: sourcePath) { throw Errors.missingSource(atPath: sourcePath) }
        
        let moduleName: String = getNextLibraryName()
        let clsName: String = getNextClassName()
        
        let projectDestination = tempLocation.appendingPathComponent(moduleName, isDirectory: true)
    
        if FileManager.default.fileExists(atPath: projectDestination.path) {
            do {
                //If library location already exists we'll try and remove it.
                try FileManager.default.removeItem(at: projectDestination)
            } catch {
                throw Errors.couldNotCleanFolder(atPath: projectDestination.path, error)
            }
        }
        
        do {
            try FileManager.default.createDirectory(at: projectDestination,
                                                    withIntermediateDirectories: true)
        } catch {
            throw Errors.couldNotCreateFolder(.project, atPath: projectDestination.path, error)
        }
        
        verbosePrint("Created temp project folder \(projectDestination.path)")
        
        
        let sourceFolder = projectDestination.appendingPathComponent("Sources", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: sourceFolder,
                                                    withIntermediateDirectories: false)
        } catch {
            throw Errors.couldNotCreateFolder(.sources, atPath: sourceFolder.path, error)
            
        }
        
        let moduleSourceFolder = sourceFolder.appendingPathComponent(moduleName, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: moduleSourceFolder,
                                                    withIntermediateDirectories: false)
        } catch {
            throw Errors.couldNotCreateFolder(.module, atPath: sourceFolder.path, error)
        }
        
        let packageSourceCode = DynamicSourceCodeGenerator.PACKAGE_FILE_CONTENTS.replacingOccurrences(of: "{MODULENAME}", with: moduleName)
        let packageFileName = projectDestination.appendingPathComponent("Package.swift", isDirectory: false)
        
        do {
            try packageSourceCode.write(to: packageFileName,
                                        atomically: false,
                                        encoding: DynamicSourceCodeGenerator.PACKAGE_FILE_ENCODING)
        } catch {
            throw Errors.unableToWriteFile(atPath: packageFileName.path, error)
        }
        
        
        let srcBuilderSrc: String!
        let srcBuilderEnc: String.Encoding!
        do {
            let builder = try DynamicSourceCodeBuilder(file: sourcePath,
                                                       fileEncoding: encoding,
                                                       className: clsName,
                                                       dSwiftModuleName: dSwiftModuleName,
                                                       dSwiftURL: dSwiftURL)
            srcBuilderSrc = try builder.generateSourceGenerator()
            srcBuilderEnc = builder.sourceEncoding
        } catch {
            throw Errors.unableToGenerateSource(for: sourcePath, error)
        }
        
        //let classFileName = moduleSourceFolder.appendingPathComponent("\(clsName).swift", isDirectory: false)
        let classFileName = moduleSourceFolder.appendingPathComponent("main.swift", isDirectory: false)
        do {
            try srcBuilderSrc.write(to: classFileName, atomically: false, encoding: srcBuilderEnc)
        } catch {
            throw Errors.unableToWriteFile(atPath: classFileName.path, error)
        }
        
        return (moduleName: moduleName, moduleLocation: projectDestination, sourceEncoding: srcBuilderEnc)
    }
    
    private func buildModule(sourcePath: String, moduleLocation: URL) throws -> String {
        verbosePrint("Compiling generator")
        var task = Process()
        
        var pipe = Pipe()
        
        
        task.executable = URL(fileURLWithPath: swiftPath)
        task.currentDirectory = URL(fileURLWithPath: moduleLocation.path)
       
        
        task.arguments = ["build"] // "--show-bin-path"
        
        #if os(macOS)
        task.standardInput = FileHandle.nullDevice
        #endif
        task.standardOutput = pipe
        task.standardError = pipe
        
        
        try task.execute()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            verbosePrint("There was an error while generating source")
            var errStr: String = ""
            let errDta = pipe.fileHandleForReading.readDataToEndOfFile()
            if let e = String(data: errDta, encoding: .utf8) {
                errStr = "\n" + e
            }
            if let r = errStr.range(of: ": error: ") {
                let idx = errStr.index(r.lowerBound, offsetBy: 2)
                errStr = String(errStr.suffix(from: idx))
            }
            if let r = errStr.range(of: "\nerror: terminated(1):") {
                errStr = String(errStr.prefix(upTo: r.lowerBound))
            }
            throw Errors.buildModuleFailed(for: sourcePath,
                                           withCode: Int(task.terminationStatus),
                                           returingError: errStr)
            //throw "Building Library for '\(sourcePath)' failed.\(task.terminationStatus).\(errStr)"
        }
        
        task = Process()
        pipe = Pipe()
        
        task.executable = URL(fileURLWithPath: swiftPath)
        task.currentDirectory = URL(fileURLWithPath: moduleLocation.path)
        
        task.arguments = ["build", "--show-bin-path"]
        
        #if os(macOS)
        task.standardInput = FileHandle.nullDevice
        #endif
        task.standardOutput = pipe
        task.standardError = pipe
        
        try task.execute()
        task.waitUntilExit()
        
        verbosePrint("Compiling completed")
        
        let modulePathData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard var modulePathStr = String(data: modulePathData, encoding: .utf8) else {
            throw Errors.unableToReadSTDOut
        }
        
        let modulePathLines = modulePathStr.split(separator: "\n").map(String.init)
        modulePathStr = modulePathLines[modulePathLines.count - 1]
        
        return modulePathStr
        
    }
    
    private func runModule(atPath path: String, havingOutputEncoding encoding: String.Encoding) throws -> String {
        verbosePrint("Running module generator \(path)")
        
        let workingFolder: String = path.deletingLastPathComponent
        let outputFile: String = workingFolder + "/" + "swift.out"
        defer { try? FileManager.default.removeItem(atPath: outputFile) }
        
        let task = Process()
        
        let pipe = Pipe()
        
        task.executable = URL(fileURLWithPath: path)
        task.currentDirectory = URL(fileURLWithPath: workingFolder)
        task.arguments = [outputFile]

        #if os(macOS)
        task.standardInput = FileHandle.nullDevice
        #endif
        task.standardOutput = pipe
        task.standardError = pipe
        
        
        try task.execute()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            verbosePrint("There was an error while running module source generator")
            var errStr: String = ""
            let errDta = pipe.fileHandleForReading.readDataToEndOfFile()
            if let e = String(data: errDta, encoding: .utf8) {
                errStr = "\n" + e
            }
            throw Errors.runModuleFailed(for: path,
                                         withCode: Int(task.terminationStatus),
                                         returingError: errStr)
        }
        
        verbosePrint("Running module completed")
        
        return try String(contentsOf: URL(fileURLWithPath: outputFile), encoding: encoding)
    }
    
    public func generateSource(from sourcePath: String,
                               havingEncoding encoding: String.Encoding? = nil) throws -> (source: String, encoding: String.Encoding) {
        
        let mod = try createModule(sourcePath: sourcePath, havingEncoding: encoding)
        defer { try? FileManager.default.removeItem(at: mod.moduleLocation) }
        
        var modulePathStr: String = try buildModule(sourcePath: sourcePath, moduleLocation: mod.moduleLocation)
        modulePathStr += "/" + mod.moduleName
        
        let src = try runModule(atPath: modulePathStr, havingOutputEncoding: mod.sourceEncoding)
        return (source: src, encoding: mod.sourceEncoding)
        
    }
    
    
    
    public func generateSource(from sourcePath: String,
                               havingEncoding encoding: String.Encoding? = nil,
                               to destinationPath: String) throws {
        self.verbosePrint("Generating source for '\(sourcePath)'")
        let s = try generateSource(from: sourcePath, havingEncoding: encoding)
        if FileManager.default.fileExists(atPath: destinationPath) {
            do {
                try FileManager.default.removeItem(atPath: destinationPath)
            } catch {
                verbosePrint("Unable to remove old version of '\(destinationPath)'")
            }
        }
        try s.source.write(toFile: destinationPath, atomically: false, encoding: s.encoding)
        do {
            //marking generated file as read-only
            try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 4444)], ofItemAtPath: destinationPath)
        } catch {
            verbosePrint("Unable to mark'\(destinationPath)' as readonly")
        }
    }
    
    /*public func generateSource(from source: URL, havingEncoding encoding: String.Encoding? = nil, to destination: URL) throws {
        guard source.isFileURL else { throw Errors.mustBeFileURL(source) }
        guard destination.isFileURL else { throw Errors.mustBeFileURL(destination) }
        try generateSource(from: source.path, havingEncoding: encoding, to: destination.path)
    }
    
    public func generateSource(from source: URL) throws -> (String, String.Encoding) {
        guard source.isFileURL else { throw Errors.mustBeFileURL(source) }
        return try self.generateSource(from: source.path)
    }*/
}
