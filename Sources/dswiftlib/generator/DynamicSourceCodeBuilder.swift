//
//  DynamicSourceCodeBuilder.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2018-12-05.
//

import Foundation
import VersionKit
import PathHelpers

public class DynamicSourceCodeBuilder {
    
    public enum Errors: Error, CustomStringConvertible {
        case missingClosingBlock(closing: String, for: String, in: String, onLine: Int)
        case missingOpeningBlock(for: String, in: String, onLine: Int)
        case invalidTagAttributes(tag: String, attributes: [String], in: String, onLine: Int)
        case invalidTagAttributeValue(tag: String, attribute: String, value: String, expecting: [String]?, in: String, onLine: Int)
        case invalidTag(tag: String, in: String, onLine: Int)
        case missingTagAttributes(tag: String, attributes: [String], in: String, onLine: Int)
        case invalidIncludedFileFormat(include: String, in: String, onLine: Int)
        case includedResourceNotFound(include: String, includeFullPath: String, in: String, onLine: Int)
        case failedToIncludeFile(include: String, in: String, onLine: Int, error: Error)
        //case foundUnprocessedInclude(include: String, in: String, onLine: Int)
        case unprocessedTag(tag: String, source: String, in: String, onLine: Int)
        case invalidDSwiftToolsVersionNumber(for: String, ver: String)
        case minimumDSwiftToolsVersionNotMet(for: String, expected: String, found: String, description: String?)
        case missingBlockAttribute(block: String, attribute: String, in: String, onLine: Int)
        case blockAttributeMissingClosingQuote(block: String, attribute: String, in: String, onLine: Int)
        case blockAttributeInvalidValue(block: String, attribute: String, value: String, expecting: String?, in: String, onLine: Int)
        
        public var description: String {
            switch self {
            case .missingClosingBlock(closing: let closing, for: let opening, in: let path, onLine: let line):
                return "\(path): Missing closing '\(closing)' for '\(opening)' starting on line \(line)"
            case .missingOpeningBlock(for: let closing, in: let path, onLine: let line):
                return "\(path): Missing opening block for '\(closing)' finishing on line \(line)"
            case .invalidTagAttributes(tag: let tag, attributes: let attribs, in: let path, onLine: let line):
                if attribs.count > 1 {
                    return "\(path): Invalid Attributes '\(attribs.map({ return "'\($0)'" }).joined(separator: ", "))' in tag '\(tag)' on line \(line)"
                } else {
                    return "\(path): Invalid Attribute '\(attribs.first!)' in tag '\(tag)' on line \(line)"
                }
            case .missingTagAttributes(tag: let tag, attributes: let attribs, in: let path, onLine: let line):
                if attribs.count > 1 {
                    return "\(path): Missing Attributes '\(attribs.map({ return "'\($0)'" }).joined(separator: " OR "))' in tag '\(tag)' on line \(line)"
                } else {
                    return "\(path): Missing Attribute '\(attribs.first!)' in tag '\(tag)' on line \(line)"
                }
            case .invalidTagAttributeValue(tag: let tag,
                                           attribute: let attrib,
                                           value: let value,
                                           expecting: let expecting,
                                           in: let path,
                                           onLine: let line):
                
                var rtn: String = "\(path): Attribute '\(tag)/\(attrib)' has an invalid value '\(value)'"
                if let exp = expecting {
                    rtn += ". Expecting" + exp.map({ return "'\($0)'" }).joined(separator: " OR ")
                }
                rtn += " on line \(line)"
                return rtn
            case .invalidTag(tag: let tag,
                             in: let path,
                             onLine: let line):
                return "\(path): Invalid tag '\(tag)' on line '\(line)'"
            case .invalidIncludedFileFormat(include: let include, let path, let line):
                return "\(path): Invalid Include File Format'\(include)' on line \(line)"
            case .includedResourceNotFound(include: let include, includeFullPath: let includeFullPath, let path, let line):
                return "\(path): Include resource '\(include)' / '\(includeFullPath)' on line \(line) not found"
            case .failedToIncludeFile(include: let include, let path, let line, let err):
                return "\(path): Failed to include '\(include)' on line \(line): \(err)"
            //case .foundUnprocessedInclude(include: let include, let path, let line):
            //    return "\(path): Found unprocessed include '\(include)' on line \(line)"
            case .unprocessedTag(tag: let tag, source: _, in: let path, onLine: let line):
                return "\(path): Found unprocessed tag '\(tag)' on line \(line)"
            case .invalidDSwiftToolsVersionNumber(let path, let ver):
                return "\(path): Invalid dswift-tools-version '\(ver)'"
            case .minimumDSwiftToolsVersionNotMet(let path, let expected, let found, let desc):
                var rtn = "\(path): Minimum dswift-tools-version '\(expected)' not met.  Current version is '\(found)'"
                if let d = desc { rtn += ". " + d }
                return rtn
            case .missingBlockAttribute(let block, let attribute, let path, let line):
                return "Block tag '\(block)' missing attribute '\(attribute)' in file '\(path)' on line \(line)"
            case .blockAttributeMissingClosingQuote(let block, let attribute, let path, let line):
                return "Block tag '\(block)' missing attribute '\(attribute)'s ending quote in file '\(path)' on line \(line)"
            case .blockAttributeInvalidValue(let block, let attribute, let value, let expecting, let path, let line):
                var rtn: String = "Block tag '\(block)' attribute '\(attribute)' has an invalid value '\(value)'"
                if let e = expecting {
                    rtn += ", expecting \(e)"
                } else {
                    rtn += " "
                }
                rtn += " in file '\(path)' on line \(line)"
                return rtn
                
            }
        }
    }
    
    
    public struct CodeBlockIdentifiers {
        
        public struct CodeBlock {
            let range: Range<String.Index>
            let type: CodeBlockDefinition
            let string: String
            
            var lines: [String] { return CodeBlock.splitBlockString(self.string) }
            
            let subBlockString: String?
            var subBlockLines: [String]? {
                guard let l = self.subBlockString else { return nil }
                return CodeBlock.splitBlockString(l)
            }
            
            public init(range: Range<String.Index>,
                        type: CodeBlockDefinition,
                        string: String,
                        subBlockString: String? = nil) {
                self.range = range
                self.type = type
                self.string = string
                self.subBlockString = subBlockString
            }
            
            private static func splitBlockString(_ string: String) -> [String] {
                return string.split(separator: "\n", omittingEmptySubsequences: false).map {
                    var rtn = String($0)
                    if String($0).hasSuffix("\r") {  rtn.removeLast() }
                    return rtn
                }
            }
            
            func generateContent(source: String,
                                 file: FSPath) throws -> GeneratedContent {
                return try self.type.generateContent(block: self,
                                                     source: source,
                                                     file: file)
            }
        }
        
        let opening: String
        let closing: String
        let tagIndicator: String
        
        let blocks: [CodeBlockDefinition]
        
        var maxOpeningBlockSize: Int {
            var maxBlockSize: Int = 0
            for b in self.blocks {
                if b.openingBrace.count > maxBlockSize { maxBlockSize  = b.openingBrace.count }
            }
            return (self.opening.count + maxBlockSize)
        }
        var minOpeningBlockSize: Int {
            var minBlockSize: Int = self.blocks[0].openingBrace.count
            for b in self.blocks {
                if b.openingBrace.count < minBlockSize { minBlockSize  = b.openingBrace.count }
            }
            return (self.opening.count + minBlockSize)
        }
        
        var maxClosingBlockSize: Int {
            var maxBlockSize: Int = 0
            for b in self.blocks {
                if b.closingBrace.count > maxBlockSize { maxBlockSize  = b.closingBrace.count }
            }
            return (self.closing.count + maxBlockSize)
        }
        var minClosingBlockSize: Int {
            var minBlockSize: Int = self.blocks[0].closingBrace.count
            for b in self.blocks {
                if b.closingBrace.count < minBlockSize { minBlockSize  = b.closingBrace.count }
            }
            return (self.closing.count  + minBlockSize)
        }
        
        init(opening: String, closing: String, tagIndicator: String, blocks: [CodeBlockDefinition]) {
            self.opening = opening
            self.closing = closing
            self.tagIndicator = tagIndicator
            
            precondition(!blocks.contains(where: { return $0.isTextBlock }),
                         "Do not provide CodeBlockDefinition.text in blocks array")
            
            
            //Make sure that the longest opening comes first
            self.blocks = blocks.sorted( by: { $0.openingBrace.count > $1.openingBrace.count } )
        }
        
        func nextBlockSet(from string: String,
                          startingAt: String.Index,
                          inFile file: FSPath) throws -> CodeBlock? {
            //If we are at the end index, we are done
            guard startingAt !=  string.endIndex else { return nil }
            // Looks for opening block brace.  If not found we return the whole string as a text block
            let stBlockIndex: String.Index? = string.range(of: self.opening, range:startingAt..<string.endIndex)?.lowerBound
            
            if let closeBlockIndex: String.Index = string.range(of: self.closing, range:startingAt..<string.endIndex)?.lowerBound {
                if stBlockIndex == nil || closeBlockIndex < stBlockIndex! {
                    let line = string.countOccurrences(of: "\n",
                                                       inRange: string.startIndex..<closeBlockIndex)
                    throw Errors.missingOpeningBlock(for: self.closing,
                                                        in: file.string,
                                                        onLine: line + 1)
                }
            }
            
            guard let startBlockIndex = stBlockIndex else {
                return CodeBlock(range: startingAt..<string.endIndex,
                                 type: BasicCodeBlockDefinition.text,
                                 string: String(string[startingAt..<string.endIndex]))
            }
            
            // Ensures that the opening of the block is at the starting index, otherwise we return a text block from startingAt to the beginning of the code block
            guard startBlockIndex == startingAt else {
                let str = String(string[startingAt..<startBlockIndex])
                return CodeBlock(range: startingAt..<startBlockIndex,
                                 type: BasicCodeBlockDefinition.text,
                                 string: str)
            }
            
            let strMaxBlockIndicator: String.Index = string.index(startBlockIndex,
                                                                  offsetBy: self.maxOpeningBlockSize,
                                                                  limitedBy: string.endIndex) ?? string.endIndex
            let stringFrom: String = String(string[startBlockIndex..<strMaxBlockIndicator])
            
            for b in self.blocks {
                var op = self.opening
                if b is TagBlockDefinition {
                    op += self.tagIndicator
                }
                op += b.openingBrace
                if stringFrom.hasPrefix(op) {
                    let ed =  b.closingBrace + self.closing
                    guard let endBlockIndex: String.Index = string.range(of: ed, range:startBlockIndex..<string.endIndex)?.lowerBound else {
                        let line = string.countOccurrences(of: "\n",
                                                           inRange: string.startIndex..<startBlockIndex)
                        throw Errors.missingClosingBlock(closing: ed,
                                                         for: op,
                                                         in: file.string,
                                                         onLine: line + 1)
                    }
                    
                    let innerOpening: String.Index = string.index(startBlockIndex, offsetBy: op.count)
                    var fullBlock: String = String(string[innerOpening..<endBlockIndex])
                    
                    if fullBlock.hasPrefix("\r") { fullBlock.removeFirst() }
                    if fullBlock.hasPrefix("\n") { fullBlock.removeFirst() }
                    
                    if fullBlock.hasSuffix("\n") {
                        fullBlock.removeLast()
                        if fullBlock.hasSuffix("\r") { fullBlock.removeLast() }
                    }
                    
                    
                    let outerEndBlockIndex: String.Index = string.index(endBlockIndex, offsetBy: ed.count)
                    
                    return CodeBlock(range: startBlockIndex..<outerEndBlockIndex,
                                     type: b,
                                     string: fullBlock)
                    
                    
                }
            }
            
            //Didn't get anywhere
            return nil
        }
        
        
    }
    
    public static let tagIndicator: String = "@"
    // The minimum dswift version to support '@include' coding block
    private static let minimumSupportedIncludeVersion: Version.SingleVersion = DSwiftTag.minimumSupportedTagVersion
    private static let minimumSupportedIncludeFolderOrOnlyOnceVersion: Version.SingleVersion = "2.0.0"
    //private static let includeCodingBlock = CodeBlockDefinition(include: "@include")
    
    private static let blockDefinitions = CodeBlockIdentifiers(opening: "<%",
                                                               closing: "%>",
                                                               tagIndicator: tagIndicator,
                                                               blocks: [
        BasicCodeBlockDefinition(basic: ""),
        BasicCodeBlockDefinition(inline: "="),
        BasicCodeBlockDefinition(class: "!"),
        BasicCodeBlockDefinition(global: "!!"),
        IncludeBlockDefinition(),
        ReferenceBlockDefinition()
    ])
    
    private var blockDefinitions: CodeBlockIdentifiers {
        return DynamicSourceCodeBuilder.blockDefinitions
    }
    
    
    private var source: String = ""
    private var file: FSPath
    public private(set) var clsName: String
    public private(set) var sourceEncoding: String.Encoding
    public let dswiftInfo: DSwiftInfo
    public let console: Console
    public let preloadedDetails: DynamicSourceCodeGenerator.PreloadedDetails
    
    public let includeFolders: [DSwiftTag.Include.Folder]
    public let includePackages: [DSwiftTag.Include.GitPackageDependency]
    public let swiftProject: SwiftProject
    
    public init(file: FSPath,
                swiftProject: SwiftProject,
                //fileEncoding: String.Encoding? = nil,
                className: String,
                dswiftInfo: DSwiftInfo,
                preloadedDetails: DynamicSourceCodeGenerator.PreloadedDetails,
                console: Console = .null,
                      using fileManager: FileManager) throws {
        
        //self.generator = generator
        self.swiftProject = swiftProject
        self.dswiftInfo = dswiftInfo
        self.console = console
        self.file = file
        self.preloadedDetails = preloadedDetails
        
        let fullFilePath = file.fullPath()
        
        let content = try preloadedDetails.getSourceContent(for: fullFilePath,
                                                            project: swiftProject,
                                                            console: console,
                                                               using: fileManager)
        
        self.source = content.content
        self.sourceEncoding = content.encoding
        
       
        self.clsName = className
        
        try DynamicSourceCodeBuilder.validateDSwiftToolsVersion(from: fullFilePath,
                                                                source: self.source,
                                                                preloadedDetails: preloadedDetails,
                                                                dSwiftVersion: self.dswiftInfo.version,
                                                                console: console)
        
        
        // If we support Include blocks, we will automatically import them before processing any other blocks
        let (processIncludesTime, processedTags) = try Timer.timeWithResults(block: try DynamicSourceCodeBuilder.processDSwiftTags(from: fullFilePath,
                                                                                                                                   project: swiftProject,
                                                                                                                                   dswiftInfo: dswiftInfo,
                                                                                                                                   preloadedDetails: preloadedDetails,
                                                                                                                                   console: console,
                                                                                                                                   using: fileManager))
        
        //print("processTags took \(processIncludesTime)(s)")
        self.source = processedTags.source
        self.includeFolders = processedTags.includeFolders
        self.includePackages = processedTags.includePackages
        
        console.printDebug("Processing Tags for '\(file)' too \(processIncludesTime)(s)", object: self)
    }
    
    
    
    public static func parseDSwiftToolsVersion(from path: FSPath,
                                             source: String,
                                             console: Console = .null) throws -> Version.SingleVersion? {
        
        guard let r = source.range(of: "//(|\\s)dswift-tools-version:", options: .regularExpression),
           r.lowerBound == source.startIndex,
           let newLineRange = source.range(of: "\n", range: r.upperBound..<source.endIndex) else {
               return nil
        }
        // Copy text after : and before \n
        var line = String(source[r.upperBound..<newLineRange.lowerBound])
        // Remove white spaces
        line = line.trimmingCharacters(in: .whitespaces)
        
        guard let verNum = Version.SingleVersion(line) else {
            throw Errors.invalidDSwiftToolsVersionNumber(for: path.string, ver: line)
        }
        
        return verNum
        
    }
    
    private static func validateDSwiftToolsVersion(from path: FSPath,
                                                   source: String,
                                                   dSwiftVersion: Version.SingleVersion,
                                                   srcRequiredVersion: Version.SingleVersion) throws {
        
        guard dSwiftVersion >= srcRequiredVersion else {
            throw Errors.minimumDSwiftToolsVersionNotMet(for: path.string,
                                                            expected: srcRequiredVersion.description,
                                                            found: dSwiftVersion.description,
                                                            description: nil)
        }
    }
    
    
    private static func validateDSwiftToolsVersion(from path: FSPath,
                                                   source: String,
                                                   preloadedDetails: DynamicSourceCodeGenerator.PreloadedDetails,
                                                   dSwiftVersion: Version.SingleVersion,
                                                   console: Console = .null) throws {
        
        guard let requiedToolsVersion = try preloadedDetails
                .getSourceDSwiftVersion(for: path,
                                        source: source,
                                        console: console) else {
            return
        }
                                                      
        
        try self.validateDSwiftToolsVersion(from: path,
                                            source: source,
                                            dSwiftVersion: dSwiftVersion,
                                            srcRequiredVersion: requiedToolsVersion)
    }
    
    public static func parseDSwiftTags(in path: FSPath,
                                       source: String,
                                       project: SwiftProject,
                                       console: Console = .null,
                                       using fileManager: FileManager) throws -> [DSwiftTag] {
    
        // Get a list of all available tags
        let supportedTags: [TagBlockDefinition] = self.blockDefinitions.blocks.compactMap {
            return $0 as? TagBlockDefinition
        }
        
        guard !supportedTags.isEmpty else { return [] }
        
        let tagBeginning = self.blockDefinitions.opening + self.blockDefinitions.tagIndicator
        
        
        var rtn: [DSwiftTag] = []
        
        
        var tagStartLookingIndex = source.startIndex
        while let startTagRange = source.range(of: tagBeginning,
                                               range: tagStartLookingIndex..<source.endIndex) {
            
            let closingBlock = self.blockDefinitions.closing
            
            guard let endTagRange = source.range(of: closingBlock, range: startTagRange.upperBound..<source.endIndex) else {
                // Could not find end of block
                let line = source.countOccurrences(of: "\n",
                                                   inRange: source.startIndex..<startTagRange.lowerBound)
                
                throw Errors.missingClosingBlock(closing: closingBlock,
                                                 for: tagBeginning,
                                                 in: path.string,
                                                 onLine: line + 1)
            }
            
            let endOfTagNameIndex = source.range(of: " ",
                                                 range: startTagRange.upperBound..<endTagRange.lowerBound)?.lowerBound ?? endTagRange.lowerBound
            
            let tagName = String(source[startTagRange.upperBound..<endOfTagNameIndex])
            
            guard let tag = supportedTags.first(where: { return $0.name == tagName }) else {
                let line = source.countOccurrences(of: "\n",
                                                   inRange: source.startIndex..<startTagRange.lowerBound)
                
                throw Errors.invalidTag(tag: tagName, in: path.string, onLine: line + 1)
            }
            
            // Working index for searching for tag attributes
            var workingIndex = endOfTagNameIndex
            
            // Skip over any whitespace
            while workingIndex < endTagRange.lowerBound &&
                    source[workingIndex].isWhitespace {
                workingIndex = source.index(after: workingIndex)
            }
            
            var attributes: [String: String] = [:]
            
            while workingIndex < endTagRange.lowerBound {
            
                var startOfAttributeNameIndex = workingIndex
                // Skip over whitespace
                while startOfAttributeNameIndex < endTagRange.lowerBound &&
                        source[startOfAttributeNameIndex].isWhitespace {
                    startOfAttributeNameIndex = source.index(after: startOfAttributeNameIndex)
                }
                // Make sure not at end of tag
                guard startOfAttributeNameIndex < endTagRange.lowerBound else {
                    // Failed to find start of tag attribute name
                    let line = source.countOccurrences(of: "\n",
                                                       inRange: source.startIndex..<startTagRange.lowerBound)
                    throw Errors.invalidTag(tag: tagName, in: path.string, onLine: line)
                }
                
                var endOfAttributeNameIndex = startOfAttributeNameIndex
                // Find '=' marking end of attribute name
                while endOfAttributeNameIndex < endTagRange.lowerBound &&
                      !source[endOfAttributeNameIndex].isWhitespace &&
                      source[endOfAttributeNameIndex] != "=" {
                    endOfAttributeNameIndex = source.index(after: endOfAttributeNameIndex)
                }
                // Make sure no whitespace
                guard !source[endOfAttributeNameIndex].isWhitespace else {
                    // Found whitespace when tring to find end of attribute name
                    let line = source.countOccurrences(of: "\n",
                                                       inRange: source.startIndex..<startTagRange.lowerBound)
                    throw Errors.invalidTag(tag: tagName, in: path.string, onLine: line)
                }
                // Make sure not at end of tag
                guard endOfAttributeNameIndex < endTagRange.lowerBound else {
                    // Failed to find end of attribute name
                    let line = source.countOccurrences(of: "\n",
                                                       inRange: source.startIndex..<startTagRange.lowerBound)
                    throw Errors.invalidTag(tag: tagName, in: path.string, onLine: line)
                }
                // Get attribute name
                let attribName = String(source[startOfAttributeNameIndex..<endOfAttributeNameIndex])
                
                
                
                var startOfAttributeValueIndex = source.index(after: endOfAttributeNameIndex)
                guard startOfAttributeValueIndex < endTagRange.lowerBound else {
                    //Missing attribute value start index
                    let line = source.countOccurrences(of: "\n",
                                                       inRange: source.startIndex..<startTagRange.lowerBound)
                    throw Errors.invalidTag(tag: tagName, in: path.string, onLine: line)
                }
                
                guard source[startOfAttributeValueIndex] == "\"" ||
                      source[startOfAttributeValueIndex] == "'" else {
                    // Expected to find start of string
                    let line = source.countOccurrences(of: "\n",
                                                       inRange: source.startIndex..<startTagRange.lowerBound)
                    throw Errors.invalidTag(tag: tagName, in: path.string, onLine: line)
                }
                // The attribute value quote (either " or ')
                let attribStringIndicator = source[startOfAttributeValueIndex]
                
                var endOfAttributeValueIndex = source.index(after: startOfAttributeValueIndex)
                while endOfAttributeValueIndex < endTagRange.lowerBound &&
                      source[endOfAttributeValueIndex] != attribStringIndicator &&
                      !source[endOfAttributeValueIndex].isNewline {
                    endOfAttributeValueIndex = source.index(after: endOfAttributeValueIndex)
                }
                
                guard !source[endOfAttributeValueIndex].isNewline else {
                    // Invalid character in attribute value
                    let line = source.countOccurrences(of: "\n",
                                                       inRange: source.startIndex..<startTagRange.lowerBound)
                    throw Errors.invalidTag(tag: tagName, in: path.string, onLine: line)
                }
                
                guard endOfAttributeValueIndex < endTagRange.lowerBound else {
                    //Missing attribute value end index
                    let line = source.countOccurrences(of: "\n",
                                                       inRange: source.startIndex..<startTagRange.lowerBound)
                    throw Errors.invalidTag(tag: tagName, in: path.string, onLine: line)
                }
                
                // Move past the opening Quote (either ' or ")
                startOfAttributeValueIndex = source.index(after: startOfAttributeValueIndex)
                let attribValue = String(source[startOfAttributeValueIndex..<endOfAttributeValueIndex])
                // Move past the ending quote
                endOfAttributeValueIndex = source.index(after: endOfAttributeValueIndex)
                attributes[attribName.lowercased()] = attribValue
                
                
                workingIndex = endOfAttributeValueIndex
                
                
                
                
                // Skip over whitespace
                while workingIndex < endTagRange.lowerBound &&
                      source[workingIndex].isWhitespace {
                    workingIndex = source.index(after: workingIndex)
                }
                
            }
            
            tagStartLookingIndex = endTagRange.upperBound
            
            let tagReference = try tag.parseTagProperties(attributes: attributes,
                                                          source: source,
                                                          path: path,
                                                          tagRange: startTagRange.lowerBound..<endTagRange.upperBound,
                                                          project: project,
                                                          console: console,
                                                          using: fileManager)
            
            rtn.append(tagReference)
            
        }
        
        return rtn
    }
    
    public struct ProcessedTags {
        //var externalReferences: ExternalReferences
        //var includeSources: [String: String]
        var includeFolders: [DSwiftTag.Include.Folder]
        var includePackages: [DSwiftTag.Include.GitPackageDependency]
        var source: String
        
        public init(//externalReferences: ExternalReferences = .init(),
                    //includeSources: [String: String] = [:],
                    includeFolders: [DSwiftTag.Include.Folder] = [],
                    includePackages: [DSwiftTag.Include.GitPackageDependency] = [],
                    source: String = "") {
            //self.externalReferences = externalReferences
            //self.includeSources = includeSources
            self.includeFolders = includeFolders
            self.includePackages = includePackages
            self.source = source
        }
        
        public mutating func append(_ folders: [DSwiftTag.Include.Folder]) {
            // Include child include folders into our include folder root
            var tempRoot = DSwiftTag.Include.Folder.root(currentChildren:  self.includeFolders)
            tempRoot.appendChildFolders(folders)
            self.includeFolders = tempRoot.childFolders
        }
        
        public mutating func append(_ folder: DSwiftTag.Include.Folder) {
            self.append([folder])
        }
        
        
        
        public mutating func append(_ dependencies: [DSwiftTag.Include.GitPackageDependency]) {
            // Include child include folders into our include folder root
            for includePackage in dependencies {
                if !self.includePackages.contains(where: { return $0.url == includePackage.url }) {
                    self.includePackages.append(includePackage)
                }
            }
        }
        
        
        public mutating func append(_ dependency: DSwiftTag.Include.GitPackageDependency) {
            self.append([dependency])
        }
        
        public mutating func append(_ processed: ProcessedTags, filePath: String) {
            // Include child include folders into our include folder root
            self.append(self.includeFolders)
            
            // Include child include packages into our include package list
            self.append(processed.includePackages)
        }
        
        public mutating func append(_ folder: DSwiftTag.Include.Folder, for path: String) {
            self.append(folder)
        }
        
        public mutating func append(_ tags: [DSwiftTag]) {
            for tag in tags {
                if case .include(let include, tagRange: _) = tag,
                   case .folder(let folder) = include {
                    self.append(folder)
                }
            }
        }
    }
    
    static func findTags(in path: FSPath,
                         source: String,
                         blockDefinitions: DynamicSourceCodeBuilder.CodeBlockIdentifiers = DynamicSourceCodeBuilder.blockDefinitions,
                         project: SwiftProject,
                         console: Console = .null,
                         using fileManager: FileManager) throws -> [DSwiftTag] {
    
        // Get a list of all available tags
        let supportedTags: [TagBlockDefinition] = blockDefinitions.blocks.compactMap {
            return $0 as? TagBlockDefinition
        }
        
        guard !supportedTags.isEmpty else { return [] }
        
        let tagBeginning = blockDefinitions.opening + blockDefinitions.tagIndicator
        //let openingBlock = self.blockDefinitions.opening + includeBlock.openingBrace
        //let closingBlock = includeBlock.closingBrace + self.blockDefinitions.closing
        
        var rtn: [DSwiftTag] = []
        
        
        var tagStartLookingIndex = source.startIndex
        while let startTagRange = source.range(of: tagBeginning,
                                               range: tagStartLookingIndex..<source.endIndex) {
            
            let closingBlock = blockDefinitions.closing
            
            guard let endTagRange = source.range(of: closingBlock, range: startTagRange.upperBound..<source.endIndex) else {
                // Could not find end of block
                let line = source.countOccurrences(of: "\n",
                                                   inRange: source.startIndex..<startTagRange.lowerBound)
                
                throw DynamicSourceCodeBuilder.Errors.missingClosingBlock(closing: closingBlock,
                                                 for: tagBeginning,
                                                                          in: path.string,
                                                 onLine: line + 1)
            }
            
            let endOfTagNameIndex = source.range(of: " ",
                                                 range: startTagRange.upperBound..<endTagRange.lowerBound)?.lowerBound ?? endTagRange.lowerBound
            
            let tagName = String(source[startTagRange.upperBound..<endOfTagNameIndex])
            
            guard let tag = supportedTags.first(where: { return $0.name == tagName }) else {
                let line = source.countOccurrences(of: "\n",
                                                   inRange: source.startIndex..<startTagRange.lowerBound)
                
                throw DynamicSourceCodeBuilder.Errors.invalidTag(tag: tagName,
                                                                 in: path.string,
                                                                 onLine: line + 1)
            }
            
            // Working index for searching for tag attributes
            var workingIndex = endOfTagNameIndex
            
            // Skip over any whitespace
            while workingIndex < endTagRange.lowerBound &&
                    source[workingIndex].isWhitespace {
                workingIndex = source.index(after: workingIndex)
            }
            
            var attributes: [String: String] = [:]
            
            while workingIndex < endTagRange.lowerBound {
            
                var startOfAttributeNameIndex = workingIndex
                // Skip over whitespace
                while startOfAttributeNameIndex < endTagRange.lowerBound &&
                        source[startOfAttributeNameIndex].isWhitespace {
                    startOfAttributeNameIndex = source.index(after: startOfAttributeNameIndex)
                }
                // Make sure not at end of tag
                guard startOfAttributeNameIndex < endTagRange.lowerBound else {
                    // Failed to find start of tag attribute name
                    let line = source.countOccurrences(of: "\n",
                                                       inRange: source.startIndex..<startTagRange.lowerBound)
                    throw DynamicSourceCodeBuilder.Errors.invalidTag(tag: tagName,
                                                                     in: path.string,
                                                                     onLine: line)
                }
                
                var endOfAttributeNameIndex = startOfAttributeNameIndex
                // Find '=' marking end of attribute name
                while endOfAttributeNameIndex < endTagRange.lowerBound &&
                      !source[endOfAttributeNameIndex].isWhitespace &&
                      source[endOfAttributeNameIndex] != "=" {
                    endOfAttributeNameIndex = source.index(after: endOfAttributeNameIndex)
                }
                // Make sure no whitespace
                guard !source[endOfAttributeNameIndex].isWhitespace else {
                    // Found whitespace when tring to find end of attribute name
                    let line = source.countOccurrences(of: "\n",
                                                       inRange: source.startIndex..<startTagRange.lowerBound)
                    throw DynamicSourceCodeBuilder.Errors.invalidTag(tag: tagName,
                                                                     in: path.string,
                                                                     onLine: line)
                }
                // Make sure not at end of tag
                guard endOfAttributeNameIndex < endTagRange.lowerBound else {
                    // Failed to find end of attribute name
                    let line = source.countOccurrences(of: "\n",
                                                       inRange: source.startIndex..<startTagRange.lowerBound)
                    throw DynamicSourceCodeBuilder.Errors.invalidTag(tag: tagName,
                                                                     in: path.string,
                                                                     onLine: line)
                }
                // Get attribute name
                let attribName = String(source[startOfAttributeNameIndex..<endOfAttributeNameIndex])
                
                
                
                var startOfAttributeValueIndex = source.index(after: endOfAttributeNameIndex)
                guard startOfAttributeValueIndex < endTagRange.lowerBound else {
                    //Missing attribute value start index
                    let line = source.countOccurrences(of: "\n",
                                                       inRange: source.startIndex..<startTagRange.lowerBound)
                    throw DynamicSourceCodeBuilder.Errors.invalidTag(tag: tagName,
                                                                     in: path.string,
                                                                     onLine: line)
                }
                
                guard source[startOfAttributeValueIndex] == "\"" ||
                      source[startOfAttributeValueIndex] == "'" else {
                    // Expected to find start of string
                    let line = source.countOccurrences(of: "\n",
                                                       inRange: source.startIndex..<startTagRange.lowerBound)
                          throw DynamicSourceCodeBuilder.Errors.invalidTag(tag: tagName,
                                                                           in: path.string,
                                                                           onLine: line)
                }
                // The attribute value quote (either " or ')
                let attribStringIndicator = source[startOfAttributeValueIndex]
                
                var endOfAttributeValueIndex = source.index(after: startOfAttributeValueIndex)
                while endOfAttributeValueIndex < endTagRange.lowerBound &&
                      source[endOfAttributeValueIndex] != attribStringIndicator &&
                      !source[endOfAttributeValueIndex].isNewline {
                    endOfAttributeValueIndex = source.index(after: endOfAttributeValueIndex)
                }
                
                guard !source[endOfAttributeValueIndex].isNewline else {
                    // Invalid character in attribute value
                    let line = source.countOccurrences(of: "\n",
                                                       inRange: source.startIndex..<startTagRange.lowerBound)
                    throw DynamicSourceCodeBuilder.Errors.invalidTag(tag: tagName,
                                                                     in: path.string,
                                                                     onLine: line)
                }
                
                guard endOfAttributeValueIndex < endTagRange.lowerBound else {
                    //Missing attribute value end index
                    let line = source.countOccurrences(of: "\n",
                                                       inRange: source.startIndex..<startTagRange.lowerBound)
                    throw DynamicSourceCodeBuilder.Errors.invalidTag(tag: tagName,
                                                                     in: path.string,
                                                                     onLine: line)
                }
                
                // Move past the opening Quote (either ' or ")
                startOfAttributeValueIndex = source.index(after: startOfAttributeValueIndex)
                let attribValue = String(source[startOfAttributeValueIndex..<endOfAttributeValueIndex])
                // Move past the ending quote
                endOfAttributeValueIndex = source.index(after: endOfAttributeValueIndex)
                attributes[attribName.lowercased()] = attribValue
                
                
                workingIndex = endOfAttributeValueIndex
                
                // Skip over whitespace
                while workingIndex < endTagRange.lowerBound &&
                      source[workingIndex].isWhitespace {
                    workingIndex = source.index(after: workingIndex)
                }
                
            }
            
            tagStartLookingIndex = endTagRange.upperBound
            
            let tagReference = try tag.parseTagProperties(attributes: attributes,
                                                          source: source,
                                                          path: path,
                                                          tagRange: startTagRange.lowerBound..<endTagRange.upperBound,
                                                          project: project,
                                                          console: console,
                                                          using: fileManager)
            
            rtn.append(tagReference)
            
        }
        
        return rtn
    }
    
    public static func processDSwiftTags(from path: FSPath,
                                         tagReplacementDetails: DynamicSourceCodeGenerator.TagReplacementDetails = .init(),
                                         project: SwiftProject,
                                         dswiftInfo: DSwiftInfo,
                                         preloadedDetails: DynamicSourceCodeGenerator.PreloadedDetails,
                                         console: Console = .null,
                                         using fileManager: FileManager) throws -> ProcessedTags {
        
        
        // Get source content
        let source = try preloadedDetails.getSourceContent(for: path,
                                                           project: project,
                                                           console: console,
                                                              using: fileManager).content
        
        var rtn = ProcessedTags(source: source)
        
        
        
        // Get source dswift tools version from content
        // otherwise return source because since
        // no tools version means no support for dsift tags
        guard let srcMinToolsVer = try preloadedDetails.getSourceDSwiftVersion(for: path,
                                                                               source: source,
                                                                               console: console) else {
            return rtn
        }
        
        // Validate dswift tools version
        try self.validateDSwiftToolsVersion(from: path,
                                            source: source,
                                            dSwiftVersion: dswiftInfo.version,
                                            srcRequiredVersion: srcMinToolsVer)
        
        // Find any dswift tags within source
        var tags = try preloadedDetails.getDSwiftTags(in: path,
                                                      source: source,
                                                      project: project,
                                                      console: console,
                                                      using: fileManager)
        
        //rtn.append(tags)
        
        // If no tags found just return source
        guard !tags.isEmpty else {
            return rtn
        }
        
        rtn.append(tags)
        
        for index in 0..<tags.count {
            //print("[\(path.lastPathComponent)]: Processing tag \(index+1)/\(tags.count)")
        //for (index, tag) in tags.enumerated() {
            let tag = tags[index]
            // Verifies dswift tools version against tag requirements
            try tag.verifyDSwiftToolsVersion(srcMinToolsVer, for: path)
            
            // Find any sequential white space from the beginning of the tag backwards
            // Until non whitespace or a new line.
            // We pass this along to the text replacement method
            // to allow it to format any multi-line text
            var preTagWhiteSpacing: String = ""
            var currentIndex = rtn.source.index(before: tag.tagRange.lowerBound)
            while rtn.source[currentIndex] == " " || rtn.source[currentIndex] == "\t" {
                preTagWhiteSpacing = String(source[currentIndex]) + preTagWhiteSpacing
                currentIndex = rtn.source.index(before: currentIndex)
            }
            
            // Get the text to replace the tag with
            let replacementDetails = try tag.replaceTagTextWith(preTagWhiteSpacing: preTagWhiteSpacing,
                                                             tagReplacementDetails: tagReplacementDetails,
                                                                project: project,
                                                             dswiftInfo: dswiftInfo,
                                                             preloadedDetails: preloadedDetails,
                                                             console: console,
                                                                using: fileManager)
            
            rtn.append(replacementDetails.includeFolders)
            rtn.append(replacementDetails.includePackages)
            
            // Fix pre white space
            var replacementText = replacementDetails.content
            if !preTagWhiteSpacing.isEmpty {
                replacementText = ""
                let replacementLines = replacementDetails.content.split(separator: "\n",
                                                                        omittingEmptySubsequences: false).map(String.init)
                for (index, line) in replacementLines.enumerated() {
                    if index > 0 { replacementText += preTagWhiteSpacing }
                    replacementText += line
                    if index < (replacementLines.count - 1) {
                        replacementText += "\n"
                    }
                }
            }
            
            // Get the string representation of the tag
            let tagString = tag.tagString(from: rtn.source)
            // Gets the difference in character count
            let changeCount = replacementText.count - tagString.count
            
            // Replace the tag range with the new text
            /*print("*** Pre Replacement ***")
            print("Replacing '\(tagString)'")
            print(rtn.source)
            print("*** Post Replacement ***")*/
            rtn.source.replaceSubrange(tag.tagRange, with: replacementText)
            //print(rtn.source)
            // Adjust all tags ranges after current tag due to source manipulation
            if index < tags.count - 1 {
                for i in (index+1)..<tags.count {
                    //print("[\(index)][\(path.lastPathComponent)]: Updated tagRange \(i+1)/\(tags.count)")
                    tags[i].adjustingTagRange(difference: changeCount)
                }
            }
            
        }
        
        return rtn
        
    }
    
    
    /// Function used to generate the last line of the top dswift comment block
    private static func generateCurrentEndOfDSwiftTopCommentBlock(dswiftInfo: DSwiftInfo) -> String {
        return "//  \(dswiftInfo.moduleName) can be found at \(dswiftInfo.url).\n\n"
    }
    /// Function used to generate the last line of the top dswift comment block
    private func generateCurrentEndOfDSwiftTopCommentBlock() -> String {
        return DynamicSourceCodeBuilder.generateCurrentEndOfDSwiftTopCommentBlock(dswiftInfo: self.dswiftInfo)
    }
    /// Function which will return an array of any variation of the last line in the dswift top comment block
    public static func generateListOfEndOfDSwiftTopCommentBlock(dswiftInfo: DSwiftInfo) -> [String] {
        var rtn: [String] = []
        let line = self.generateCurrentEndOfDSwiftTopCommentBlock(dswiftInfo: dswiftInfo)
        rtn.append(line)
        if line.contains("\r\n") {
            // Add last time of top comment block with LF not CRLF as for possible
            // testing agains file generated on linxu/unix
            rtn.append(line.replacingOccurrences(of: "\r\n", with: "\n"))
        } else if line.contains("\n") {
            // Add last time of top comment block with CRLF not just LF as for possible
            // testing agains file generated on windows (if ever supported)
            rtn.append(line.replacingOccurrences(of: "\n", with: "\r\n"))
        }
        return rtn
    }
    
    func generateSourceGenerator() throws -> String {
        var generatorContent: String = ""
        var globalContent: String = ""
        var classContent: String = ""
        var lastBlockEnding: String.Index = self.source.startIndex
        
         while let block = try blockDefinitions.nextBlockSet(from: self.source,
                                                             startingAt: lastBlockEnding,
                                                             inFile: self.file) {
             lastBlockEnding = block.range.upperBound
             
             let def = try block.generateContent(source: self.source, file: self.file)
             if let val = def.classContent {
                 classContent += val
                 if !val.hasSuffix("\n") { classContent += "\n" }
             } else if let val = def.generatorContent {
                 generatorContent += val
                 if !val.hasSuffix("\n") { generatorContent += "\n" }
             } else if let val = def.globalContent {
                 globalContent += val
                 if !val.hasSuffix("\n") { globalContent += "\n" }
             }
        }
        var completeSource: String = "\nimport Foundation"
        for package in self.includePackages {
            for imp in package.packageNames {
                completeSource += "\nimport \(imp)"
            }
        }
        completeSource += "\n\n"
        completeSource += """
        public class Out {
            public var buffer: String = ""
            public init() { }
        
            public func write(_ string: String) {
                self.buffer += string
            }
            public func println(_ string: String) {
                self.write(string + "\\n")
            }
        }
        
        public func +=(lhs: inout Out, rhs: String) {
            lhs.buffer += rhs
        }
        
        """
        if !globalContent.isEmpty {
            completeSource += "\n\n\n" + globalContent + "\n\n"
        }
        
        completeSource += "public class \(clsName): NSObject {\n\n"
        completeSource += classContent
        if !classContent.isEmpty {
            completeSource += "\n\n"
        }
        completeSource += "\tpublic override var description: String { return generate() }\n\n"
        
        completeSource += "\n\tpublic func generate() -> String {\n"
        completeSource += "\t\tlet out = Out()\n\n"
        completeSource += "\t\tvar sourceBuilder = out\n\n"
        
        completeSource += "\t\tsourceBuilder += \"//  This file was dynamically generated from '\(self.file.lastComponent)' by \(self.dswiftInfo.moduleName) v\(self.dswiftInfo.version).  Please do not modify directly.\\n\"\n"
        //completeSource += "\t\tsourceBuilder += \"//  \(self.dswiftInfo.moduleName) can be found at \(self.dswiftInfo.url).\\n\\n\"\n"
        var lastTopCommentLine = self.generateCurrentEndOfDSwiftTopCommentBlock()
        // we must escape the '\' so when writing it to its own swift file it strips one level out
        // eg: for \n we must do \\n
        for replacement in [("\\", "\\\\"), ("\r", "\\r"),("\n", "\\n"), ("\"", "\\\"")] {
            lastTopCommentLine = lastTopCommentLine.replacingOccurrences(of: replacement.0,
                                                                         with: replacement.1)
        }
        completeSource += "\t\tsourceBuilder += \"\(lastTopCommentLine)\"\n"
        completeSource += generatorContent
        completeSource += "\n\t\treturn sourceBuilder.buffer\n"
        completeSource += "\t}\n"
        completeSource += "}\n"
        completeSource += "\n"
        completeSource += "if CommandLine.arguments.count != 2 {\n"
        completeSource += "\t print(\"Invalid parameters\")\n"
        completeSource += "} else {\n"
        completeSource += "\t let srcEncoding = String.Encoding(rawValue: \(self.sourceEncoding.rawValue))\n"
        completeSource += "\t let gen = \(clsName)()\n"
        completeSource += "\t let src = gen.generate()\n"
        completeSource += "\t try src.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), atomically: true, encoding: srcEncoding)\n"
        completeSource += "}"
        
        return completeSource
        
    }
}
