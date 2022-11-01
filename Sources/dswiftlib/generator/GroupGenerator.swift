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
import PathHelpers



/// Generator class that contains multiple child generators
public class GroupGenerator: DynamicGenerator {
    
    private static let GENERATORS: [DynamicGenerator.Type] = [DynamicSourceCodeGenerator.self, StaticFileSourceCodeGenerator.self]
    
    private var generators: [DynamicGenerator] = []
    public var dswiftInfo: DSwiftInfo { return self.generators.first!.dswiftInfo }
    public var console: Console { return self.generators.first!.console }
    
    public var supportedExtensions: [FSExtension] {
        var rtn: [FSExtension] = []
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
                         tempDir: FSPath,
                         console: Console) throws {
        var generators: [DynamicGenerator] = []

        for generator in GroupGenerator.GENERATORS {
            generators.append(try generator.init(swiftCLI: swiftCLI,
                                                 dswiftInfo: dswiftInfo,
                                                 tempDir: tempDir,
                                                 console: console))
        }
        
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
    
    
    private func getGenerator(for source: FSPath) -> DynamicGenerator? {
        for generator in self.generators {
            if generator.isSupportedFile(source) {
               return generator
            }
        }
        return nil
    }
    
    private func getGenerator(for source: XcodeFileSystemURLResource) -> DynamicGenerator? {
        return self.getGenerator(for: FSPath(source.path))
    }
    
    public func generatedFilePath(for source: FSPath) throws -> FSPath {
        guard let generator = self.getGenerator(for: source) else {
            throw DynamicGeneratorErrors.noSupportedGenerator(ext: source.extension?.description ?? "")
        }
        return try generator.generatedFilePath(for: source)
    }
    
    public func generatedFileExists(for source: FSPath) throws -> Bool {
        guard let generator = self.getGenerator(for: source) else {
            throw DynamicGeneratorErrors.noSupportedGenerator(ext: source.extension?.description ?? "")
        }
        return try generator.generatedFileExists(for: source)
    }
    public func requiresSourceCodeGeneration(for source: FSPath) throws -> Bool {
        guard let generator = self.getGenerator(for: source) else {
            throw DynamicGeneratorErrors.noSupportedGenerator(ext: source.extension?.description ?? "")
        }
        return try generator.requiresSourceCodeGeneration(for: source)
    }
    
    public func clean(folder: FSPath,
                      using fileManager: FileManager) throws {
        var errors: [Error] = []
        for generator in self.generators {
            do {
                try generator.clean(folder: folder, using: fileManager)
            } catch {
                errors.append(error)
            }
        }
        if errors.count > 0 {
            throw DynamicGeneratorErrors.compoundError(errors)
        }
    }
    public func canAddToXcodeProject(file: FSPath) -> Bool {
        guard let generator = self.getGenerator(for: file) else {
           return false
        }
        return generator.canAddToXcodeProject(file: file)
    }
    
    public func updateXcodeProject(xcodeFile: XcodeFileSystemURLResource,
                                   inGroup group: XcodeGroup,
                                   havingTarget target: XcodeTarget,
                                   includeGeneratedFilesInXcodeProject: Bool,
                                   using fileManager: FileManager) throws -> Bool {
        guard let generator = self.getGenerator(for: xcodeFile) else {
            throw DynamicGeneratorErrors.noSupportedGenerator(ext: xcodeFile.pathExtension.lowercased())
        }
        self.console.printVerbose("\(type(of: self)).updateXcodeProject Found Generator \(type(of: generator)) for file '\(xcodeFile.path)'", object: self)
        return try generator.updateXcodeProject(xcodeFile: xcodeFile,
                                                inGroup: group,
                                                havingTarget: target,
                                                includeGeneratedFilesInXcodeProject: includeGeneratedFilesInXcodeProject,
                                                using: fileManager)
    }
    public func languageForXcode(file: XcodeFileSystemURLResource) -> String? {
        guard let generator = self.getGenerator(for: file) else {
            return nil
        }
        return generator.languageForXcode(file: file)
    }
    
    public func explicitFileTypeForXcode(file: XcodeFileSystemURLResource) -> XcodeFileType? {
        guard let generator = self.getGenerator(for: file) else {
            return nil
        }
        return generator.explicitFileTypeForXcode(file: file)
    }
    
    public func generateSource(from source: FSPath,
                               to destination: FSPath,
                               project: SwiftProject,
                               lockGenFiles: Bool,
                               using fileManager: FileManager) throws {
        guard let generator = self.getGenerator(for: source) else {
            throw DynamicGeneratorErrors.noSupportedGenerator(ext: source.extension?.description ?? "")
        }
        self.console.printVerbose("Generating source code from '\(source)' using \(type(of: generator)) generator", object: self)
        return try generator.generateSource(from: source,
                                            to: destination,
                                            project: project,
                                            lockGenFiles: lockGenFiles,
                                            using: fileManager)
        
    }
}
