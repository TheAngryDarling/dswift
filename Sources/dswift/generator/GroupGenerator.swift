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
            case .noSupportedGenerator(ext: let ext): return "No supported genrator found for extension '\(ext)'"
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
    /// Method for cleaning a given folder of any generated source files
    func clean(folder: URL) throws
    /// A method to test if the current file can be added to a Xcode Project File
    func canAddToXcodeProject(file: URL) -> Bool
    /// A method to test if the current file can be added to a Xcode Project File
    func canAddToXcodeProject(file: String) -> Bool
    
    //func languageForXcode(file: URL) -> String?
    func languageForXcode(file: String) -> String?
    
    //func explicitFileTypeForXcode(file: URL) -> XcodeFileType?
    func explicitFileTypeForXcode(file: String) -> XcodeFileType?
    
    /// Method for generating a source code from the given file
    func generateSource(from: String, havingEncoding: String.Encoding?, to: String) throws
    /// Method for generating a source code from the given file
    func generateSource(from source: URL, havingEncoding encoding: String.Encoding?, to destination: URL) throws
    /// Initializer for creating a new generator
    init(_ swiftPath: String,
         _ dSwiftModuleName: String,
         _ dSwiftURL: String,
         _ print: @escaping PRINT_SIG,
         _ verbosePrint: @escaping PRINT_SIG,
         _ debugPrint: @escaping PRINT_SIG) throws
}
public extension DynamicGenerator {
    
    init(swiftPath: String = "/usr/bin/swift",
         dSwiftModuleName: String,
         dSwiftURL: String,
         print: @escaping PRINT_SIG = { (message, filename, line, funcname) -> Void in Swift.print(message, terminator: "") },
         verbosePrint: @escaping PRINT_SIG = { (message, filename, line, funcname) -> Void in return },
         debugPrint: @escaping PRINT_SIG = { (message, filename, line, funcname) -> Void in Swift.debugPrint(message, terminator: "") }) throws {
        try self.init(swiftPath, dSwiftModuleName, dSwiftURL, print, verbosePrint, debugPrint)
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
                
                if _extensions.contains(child.pathExtension.lowercased()) {
                    let generatedFile = child.deletingPathExtension().appendingPathExtension("swift")
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
        for generator in self.generators {
            if generator.isSupportedFile(file) {
                if generator.canAddToXcodeProject(file: file) { return true }
            }
        }
        return false
    }
    public func languageForXcode(file: String) -> String? {
        for generator in self.generators {
            if generator.isSupportedFile(file) {
                if let lng = generator.languageForXcode(file: file) {
                    return lng
                }
            }
        }
        return nil
    }
    
    public func explicitFileTypeForXcode(file: String) -> XcodeFileType? {
        for generator in self.generators {
            if generator.isSupportedFile(file) {
                if let type = generator.explicitFileTypeForXcode(file: file) {
                    return type
                }
            }
        }
        return nil
    }
    
    public func generateSource(from source: String, havingEncoding: String.Encoding?, to destination: String) throws {
        for generator in self.generators {
            if generator.isSupportedFile(source) {
                verbosePrint("Generating source code from '\(source)' using \(type(of: generator)) generator")
                try generator.generateSource(from: source, havingEncoding: havingEncoding, to: destination)
                return
            }
        }
        let ext = source.pathExtension.lowercased()
        throw DynamicGeneratorErrors.noSupportedGenerator(ext: ext)
    }
}
