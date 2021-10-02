//
//  GroupGenerator.swift
//  dswift
//
//  Created by Tyler Anger on 2019-09-12.
//

import Foundation
import XcodeProj

public enum DynamicGeneratorErrors: Error, CustomStringConvertible {
     case noSupportedGenerator(ext: String)
    case mustBeFileURL(URL)
    case compoundError([Error])
    
    public var description: String {
        switch self {
            case .noSupportedGenerator(ext: let ext): return "No supported generator found for extension '\(ext)'"
            case .mustBeFileURL(let url):  return "URL '\(url)' must be a file url"
            case .compoundError(let errors):
                var rtn: String = ""
                for err in errors {
                    if !rtn.isEmpty { rtn += "\n" }
                    rtn += "\(err)"
                }
                return rtn
        }
    }
}

public protocol DynamicGenerator {
    typealias PRINT_SIG = (_ message: String, _ filename: String, _ line: Int, _ funcname: String) -> Void
    
    /// The supported extensions for the given generator
    var supportedExtensions: [String] { get }
    // Checks to see if there are supported files within the given folder
    func containsSupportedFiles(inFolder folder: URL) throws -> Bool
    /// Method for cleaning a given folder of any generated source files
    func clean(folder: URL) throws
    /// A method to test if the current file can be added to a Xcode Project File
    func canAddToXcodeProject(file: URL) -> Bool
    /// A method to test if the current file can be added to a Xcode Project File
    func canAddToXcodeProject(file: String) -> Bool
    
    /// A method to test if the current file can be added to a Xcode Project File
    func updateXcodeProject(xcodeFile: XcodeFileSystemURLResource, inGroup group: XcodeGroup, havingTarget target: XcodeTarget) throws -> Bool
    
    //func languageForXcode(file: URL) -> String?
    func languageForXcode(file: String) -> String?
    
    //func explicitFileTypeForXcode(file: URL) -> XcodeFileType?
    func explicitFileTypeForXcode(file: String) -> XcodeFileType?
    
    /// Method for generating a source code from the given file
    func generateSource(from: String, havingEncoding: String.Encoding?, to: String) throws
    /// Method for generating a source code from the given file
    func generateSource(from source: URL, havingEncoding encoding: String.Encoding?, to destination: URL) throws
    /// Returns the generated source file path for the given source
    func generatedFilePath(for source: String) throws -> String
    /// Returns the generated source file path for the given source
    func generatedFilePath(for source: URL) throws -> URL
    /// Check to see if generated source code file exists for the given file
    func generatedFileExists(for source: String) throws -> Bool
    /// Check to see if generated source code file exists for the given file
    func generatedFileExists(for source: URL) throws -> Bool
    /// Checks to see if source code generation is required
    func requiresSourceCodeGeneration(for source: String) throws -> Bool
    /// Checks to see if source code generation is required
    func requiresSourceCodeGeneration(for source: URL) throws -> Bool
    
    /// Initializer for creating a new generator
    init(_ swiftPath: String,
         _ dSwiftModuleName: String,
         _ dSwiftURL: String,
         _ print: @escaping PRINT_SIG,
         _ verbosePrint: @escaping PRINT_SIG,
         _ debugPrint: @escaping PRINT_SIG) throws
}
public extension DynamicGenerator {
    
    init(swiftPath: String = DSwiftSettings.defaultSwiftPath,
         dSwiftModuleName: String,
         dSwiftURL: String,
         print: @escaping PRINT_SIG = { (message, filename, line, funcname) -> Void in Swift.print(message, terminator: "") },
         verbosePrint: @escaping PRINT_SIG = { (message, filename, line, funcname) -> Void in return },
         debugPrint: @escaping PRINT_SIG = { (message, filename, line, funcname) -> Void in Swift.debugPrint(message, terminator: "") }) throws {
        try self.init(swiftPath, dSwiftModuleName, dSwiftURL, print, verbosePrint, debugPrint)
    }
    
    func generatedFilePath(for source: String) throws -> String {
        return source.deletingPathExtension + ".swift"
    }
    func generatedFilePath(for source: URL) throws -> URL {
        return source.deletingPathExtension().appendingPathExtension("swift")
    }
    
    func generatedFileExists(for source: String) throws -> Bool {
        let destination = try generatedFilePath(for: source)
        return FileManager.default.fileExists(atPath: destination)
    }
    func generatedFileExists(for source: URL) throws -> Bool {
        return try generatedFileExists(for: source.path)
    }
    /// Check to see if the generated fiel for the source file does not exist or that the destination file is older than the source file
    func checkGeneratedFilesDoesNotExistOrIsOutOfSync(for source: URL, destination: URL) throws -> Bool {
        guard FileManager.default.fileExists(atPath: destination.path) else { return true }
        
        verbosePrint("[\(source.lastPathComponent), \(destination.lastPathComponent)] Getting file modification dates")
        guard let srcMod = source.pathModificationDate, let desMod = destination.pathModificationDate else {
            return true
        }
        // Source is newer than destination, meaning we must rebuild
        verbosePrint("[\(source.lastPathComponent), \(destination.lastPathComponent)] Comparing modification dates")
        guard srcMod <= desMod else { return true }
        
        return false
        
    }
    /// Check to see if the generated fiel for the source file does not exist or that the destination file is older than the source file
    func checkGeneratedFilesDoesNotExistOrIsOutOfSync(for source: URL) throws -> Bool {
        return try checkGeneratedFilesDoesNotExistOrIsOutOfSync(for: source,
                                                                   destination: try generatedFilePath(for: source))
    }
    func checkForFailedGenerationCommentInDestination(for source: URL, destination: URL) throws -> Bool {
        verbosePrint("[\(destination.lastPathComponent)] Checking for failed comment")
        verbosePrint("[\(destination.lastPathComponent)] Loading file")
        verbosePrint("[\(destination.lastPathComponent)] Reachable: \(try destination.checkResourceIsReachable())")
        var enc: String.Encoding = .utf8
        let fileContents = try String(contentsOf: destination, foundEncoding: &enc)
        verbosePrint("[\(destination.lastPathComponent)] Looking at file")
        if fileContents.contains("// Failed to generate source code.") { return true }
        verbosePrint("[\(destination.lastPathComponent)] Generated source is up-to-date")
        return false
    }
    func checkForFailedGenerationCommentInDestination(for source: URL) throws -> Bool {
        return try checkForFailedGenerationCommentInDestination(for: source,
                                                                destination: try generatedFilePath(for: source))
    }
    func requiresSourceCodeGeneration(for source: URL) throws -> Bool {
        
        let destination = try generatedFilePath(for: source)
        
        guard !(try self.checkGeneratedFilesDoesNotExistOrIsOutOfSync(for: source, destination: destination)) else {
            return true
        }
        
        guard !(try self.checkForFailedGenerationCommentInDestination(for: source, destination: destination)) else {
            return true
        }
        
        return false
        
    }
    func requiresSourceCodeGeneration(for source: String) throws -> Bool {
        return try requiresSourceCodeGeneration(for: URL(fileURLWithPath: source))
    }
    
    func generateSource(from source: String, to destination: String) throws {
        try self.generateSource(from: source, havingEncoding: nil, to: destination)
    }
    
    func generateSource(from source: URL, havingEncoding encoding: String.Encoding?, to destination: URL) throws {
        guard source.isFileURL else { throw DynamicGeneratorErrors.mustBeFileURL(source) }
        guard destination.isFileURL else { throw DynamicGeneratorErrors.mustBeFileURL(destination) }
        try self.generateSource(from: source.path, havingEncoding: encoding, to: destination.path)
    }
    func generateSource(from source: URL, to destination: URL) throws {
        try self.generateSource(from: source, havingEncoding: nil, to: destination)
    }
    
    private var _extensions: [String]  { return  self.supportedExtensions.map( { return $0.lowercased() }) }
    func isSupportedFile(_ file: String) -> Bool {
        let ext = file.pathExtension.lowercased()
        guard !ext.isEmpty else { return false }
        return self._extensions.contains(ext)
    }
    func isSupportedFile(_ file: URL) -> Bool {
        return self.isSupportedFile(file.path)
    }
    
    func canAddToXcodeProject(file: URL) -> Bool {
        return self.isSupportedFile(file.path)
    }
    func canAddToXcodeProject(file: String) -> Bool {
        return self.isSupportedFile(file)
    }
    
    func languageForXcode(file: URL) -> String? {
        return self.languageForXcode(file: file.path)
    }
    func explicitFileTypeForXcode(file: URL) -> XcodeFileType? {
        return self.explicitFileTypeForXcode(file: file.path)
    }
    
    func containsSupportedFiles(inFolder folder: URL) throws -> Bool {
        guard folder.isFileURL else { throw DynamicGeneratorErrors.mustBeFileURL(folder) }
        let children = try FileManager.default.contentsOfDirectory(at: folder,
                                                                   includingPropertiesForKeys: nil)
        var folders: [URL] = []
        for child in children {
            if let r = try? child.checkResourceIsReachable(), r {
                
                guard !child.isPathDirectory else {
                    folders.append(child)
                    continue
                }
                guard child.isPathFile else { continue }
                
                if self.isSupportedFile(child) {
                    return true
                }
            }
        }
        
        for subFolder in folders {
            if (try self.containsSupportedFiles(inFolder: subFolder)) {
                return true
            }
        }
        
        return false
    }
    
    func clean(folder: URL) throws {
        guard folder.isFileURL else { throw DynamicGeneratorErrors.mustBeFileURL(folder) }
        let children = try FileManager.default.contentsOfDirectory(at: folder,
                                                                   includingPropertiesForKeys: nil)
        var folders: [URL] = []
        for child in children {
            if let r = try? child.checkResourceIsReachable(), r {
                
                guard !child.isPathDirectory else {
                    folders.append(child)
                    continue
                }
                guard child.isPathFile else { continue }
                
                if self.isSupportedFile(child) {
                    let generatedFile = try self.generatedFilePath(for: child)
                    if let gR = try? generatedFile.checkResourceIsReachable(), gR {
                        
                        do {
                            
                            try FileManager.default.removeItem(at: generatedFile)
                            verbosePrint("Removed generated file '\(generatedFile.path)'")
                            
                        } catch {
                            print("Unable to remove generated file '\(generatedFile.path)'")
                            print(error)
                        }
                    }
                }
            }
            
            
            
        }
        
        for subFolder in folders {
            try self.clean(folder: subFolder)
        }
    }
    
}

/// Generator class that contains multiple child generators
public class GroupGenerator: DynamicGenerator {
    private static let GENERATORS: [DynamicGenerator.Type] = [DynamicSourceCodeGenerator.self, StaticFileSourceCodeGenerator.self]
    
   
    
    
    private var generators: [DynamicGenerator] = []
    
    public var supportedExtensions: [String] {
        var rtn: [String] = []
        for generator in self.generators {
            rtn.append(contentsOf: generator.supportedExtensions)
        }
        return rtn
    }
    
    required public init(_ swiftPath: String,
                        _ dSwiftModuleName: String,
                        _ dSwiftURL: String,
                        _ print: @escaping PRINT_SIG,
                        _ verbosePrint: @escaping PRINT_SIG,
                        _ debugPrint: @escaping PRINT_SIG) throws {
        
        for generator in GroupGenerator.GENERATORS {
            generators.append(try generator.init(swiftPath,
                                                 dSwiftModuleName,
                                                 dSwiftURL,
                                                 print,
                                                 verbosePrint,
                                                 debugPrint))
        }
    }
    
    private func getGenerator(for source: String) -> DynamicGenerator? {
        for generator in self.generators {
            if generator.isSupportedFile(source) {
               return generator
            }
        }
        return nil
    }
    
    private func getGenerator(for source: URL) -> DynamicGenerator? {
        return self.getGenerator(for: source.path)
    }
    
    public func generatedFilePath(for source: String) throws -> String {
        guard let generator = self.getGenerator(for: source) else {
            throw DynamicGeneratorErrors.noSupportedGenerator(ext: source.pathExtension.lowercased())
        }
        return try generator.generatedFilePath(for: source)
    }
    public func generatedFilePath(for source: URL) throws -> URL {
        guard let generator = self.getGenerator(for: source) else {
            throw DynamicGeneratorErrors.noSupportedGenerator(ext: source.pathExtension.lowercased())
        }
        return try generator.generatedFilePath(for: source)
    }
    
    public func generatedFileExists(for source: String) throws -> Bool {
        guard let generator = self.getGenerator(for: source) else {
            throw DynamicGeneratorErrors.noSupportedGenerator(ext: source.pathExtension.lowercased())
        }
        return try generator.generatedFileExists(for: source)
    }
    public func generatedFileExists(for source: URL) throws -> Bool {
        guard let generator = self.getGenerator(for: source) else {
            throw DynamicGeneratorErrors.noSupportedGenerator(ext: source.pathExtension.lowercased())
        }
        return try generator.generatedFileExists(for: source)
    }
    public func requiresSourceCodeGeneration(for source: String) throws -> Bool {
        guard let generator = self.getGenerator(for: source) else {
            throw DynamicGeneratorErrors.noSupportedGenerator(ext: source.pathExtension.lowercased())
        }
        return try generator.requiresSourceCodeGeneration(for: source)
    }
    public func requiresSourceCodeGeneration(for source: URL) throws -> Bool {
        guard let generator = self.getGenerator(for: source) else {
            throw DynamicGeneratorErrors.noSupportedGenerator(ext: source.pathExtension.lowercased())
        }
        return try generator.requiresSourceCodeGeneration(for: source)
    }
    
    public func clean(folder: URL) throws {
        var errors: [Error] = []
        for generator in self.generators {
            do {
                try generator.clean(folder: folder)
            } catch {
                errors.append(error)
            }
        }
        if errors.count > 0 {
            throw DynamicGeneratorErrors.compoundError(errors)
        }
    }
    public func canAddToXcodeProject(file: String) -> Bool {
        guard let generator = self.getGenerator(for: file) else {
           return false
        }
        return generator.canAddToXcodeProject(file: file)
    }
    
    public func updateXcodeProject(xcodeFile: XcodeFileSystemURLResource, inGroup group: XcodeGroup, havingTarget target: XcodeTarget) throws -> Bool {
        guard let generator = self.getGenerator(for: xcodeFile.path) else {
            throw DynamicGeneratorErrors.noSupportedGenerator(ext: xcodeFile.pathExtension.lowercased())
        }
        verbosePrint("\(type(of: self)).updateXcodeProject Found Generator \(type(of: generator)) for file '\(xcodeFile.path)'")
        return try generator.updateXcodeProject(xcodeFile: xcodeFile, inGroup: group, havingTarget: target)
    }
    public func languageForXcode(file: String) -> String? {
        guard let generator = self.getGenerator(for: file) else {
            return nil
        }
        return generator.languageForXcode(file: file)
    }
    
    public func explicitFileTypeForXcode(file: String) -> XcodeFileType? {
        guard let generator = self.getGenerator(for: file) else {
            return nil
        }
        return generator.explicitFileTypeForXcode(file: file)
    }
    
    public func generateSource(from source: String, havingEncoding: String.Encoding?, to destination: String) throws {
        guard let generator = self.getGenerator(for: source) else {
            throw DynamicGeneratorErrors.noSupportedGenerator(ext: source.pathExtension.lowercased())
        }
        verbosePrint("Generating source code from '\(source)' using \(type(of: generator)) generator")
        return try generator.generateSource(from: source, havingEncoding: havingEncoding, to: destination)
        
    }
}
