//
//  GroupGenerator.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2019-09-12.
//

import Foundation
import VersionKit
import XcodeProj
import CLICapture



/// Generator class that contains multiple child generators
public class GroupGenerator: DynamicGenerator {
    
    
    private static let GENERATORS: [DynamicGenerator.Type] = [DynamicSourceCodeGenerator.self, StaticFileSourceCodeGenerator.self]
    
    private var generators: [DynamicGenerator] = []
    public var dswiftInfo: DSwiftInfo { return self.generators.first!.dswiftInfo }
    public var console: Console { return self.generators.first!.console }
    
    public var supportedExtensions: [String] {
        var rtn: [String] = []
        for generator in self.generators {
            rtn.append(contentsOf: generator.supportedExtensions)
        }
        return rtn
    }
    
    public init(generators: [DynamicGenerator]) throws {
        
        precondition(!generators.isEmpty, "Generators can not be empty")
        
        self.generators = generators
    }
    
    public required init(swiftCLI: CLICapture,
                         dswiftInfo: DSwiftInfo,
                         console: Console) throws {
        
        var generators: [DynamicGenerator] = []

        for generator in GroupGenerator.GENERATORS {
            generators.append(try generator.init(swiftCLI: swiftCLI,
                                                 dswiftInfo: dswiftInfo,
                                                 console: console))
        }
        
        self.generators = generators
        
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
    
    public func updateXcodeProject(xcodeFile: XcodeFileSystemURLResource,
                                   inGroup group: XcodeGroup,
                                   havingTarget target: XcodeTarget,
                                   includeGeneratedFilesInXcodeProject: Bool) throws -> Bool {
        guard let generator = self.getGenerator(for: xcodeFile.path) else {
            throw DynamicGeneratorErrors.noSupportedGenerator(ext: xcodeFile.pathExtension.lowercased())
        }
        self.console.printVerbose("\(type(of: self)).updateXcodeProject Found Generator \(type(of: generator)) for file '\(xcodeFile.path)'", object: self)
        return try generator.updateXcodeProject(xcodeFile: xcodeFile,
                                                inGroup: group,
                                                havingTarget: target,
                                                includeGeneratedFilesInXcodeProject: includeGeneratedFilesInXcodeProject)
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
    
    public func generateSource(from source: String,
                               to destination: String,
                               project: SwiftProject,
                               lockGenFiles: Bool) throws {
        guard let generator = self.getGenerator(for: source) else {
            throw DynamicGeneratorErrors.noSupportedGenerator(ext: source.pathExtension.lowercased())
        }
        self.console.printVerbose("Generating source code from '\(source)' using \(type(of: generator)) generator", object: self)
        return try generator.generateSource(from: source,
                                            to: destination,
                                            project: project,
                                            lockGenFiles: lockGenFiles)
        
    }
}
