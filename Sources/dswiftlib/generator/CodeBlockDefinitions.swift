//
//  CodeBlockDefinitions.swift
//  dswiftlibTests
//
//  Created by Tyler Anger on 2021-12-05.
//

import Foundation
import PathHelpers

public struct GeneratedContent {
    public var generatorContent: String?
    public var globalContent: String?
    public var classContent: String?
    
    public init(generatorContent: String? = nil,
                globalContent: String? = nil,
                classContent: String? = nil) {
        self.generatorContent = generatorContent
        self.globalContent = globalContent
        self.classContent = classContent
    }
    
    public init(generatorContent: String) {
        self.generatorContent = generatorContent
        self.globalContent = nil
        self.classContent = nil
    }
    
    public init(globalContent: String) {
        self.generatorContent = nil
        self.globalContent = globalContent
        self.classContent = nil
    }
    
    public init(classContent: String) {
        self.generatorContent = nil
        self.globalContent = nil
        self.classContent = classContent
    }
}
/// Protocol defining a DSwift block
public protocol CodeBlockDefinition {
    /// The opening sequence of characters of the DSwift block
    var openingBrace: String { get }
    /// The closing squence of characters of the DSwift block
    var closingBrace: String { get }
    /// Indicator if the block content text content
    var isTextBlock: Bool { get }
    
    /// Generate the content regarding the CodeBlockDefinition with the CodeBlock
    /// - Parameters:
    ///    - block: Structure containing the identified Code Definition Block Details
    ///    - source: The string containing the content of the source DSwift file
    ///    - file: The path to the DSwift file
    /// - Returns: Returns the GeneratedContent object that contains the generated content for the file
    func generateContent(block: DynamicSourceCodeBuilder.CodeBlockIdentifiers.CodeBlock,
                         source: String,
                         file: FSPath) throws -> GeneratedContent
}
/// Enum defining basic text code blocks
/// That do not need any extra processing after retrieving the body
public enum BasicCodeBlockDefinition: CodeBlockDefinition {
    /// Basic code block.  Replace block with body
    case basic(opening: String, closing: String)
    /// Class code block.  Remove block and put body outside of generator method
    case `class`(opening: String, closing: String)
    /// Global code block.  Remove block and put bod youtside of generator class
    case global(opening: String, closing: String)
    /// Inline code block. Body text gets added to generator method output
    case inline(opening: String, closing: String)
    /// Inline code block. Body text gets added to generator method output
    case text
    
    /// The opening brace of a code block
    public var openingBrace: String {
        switch (self) {
            case .basic(let opening, _) : return opening
            case .`class`(let opening, _): return opening
            case .global(let opening, _): return opening
            case .inline(let opening, _): return opening
            //case .include(let opening, _): return opening
            case .text: return ""
        }
    }
    
    /// The closing brace of a code block
    public var closingBrace: String {
        switch (self) {
            case .basic(_, let closing) : return closing
            case .`class`(_, let closing): return closing
            case .global(_, let closing): return closing
            case .inline(_, let closing): return closing
            //case .include(_, let closing): return closing
            case .text: return ""
        }
    }
    
    
    
    /// Indicator if the current code block is a basic block
    public var isBasicBlock: Bool {
        if case .basic = self { return true }
        else { return false }
    }
    
    /// Indicator if the current code block is a static block
    public var isStaticBlock: Bool {
        if case .`class`(_, _) = self { return true }
        else { return false }
    }
    
    /// Indicator if the current code block is an inline block
    public var isInlineBlock: Bool {
        if case .inline = self { return true }
        else { return false }
    }
    /// Indicator if the current code block is a text block
    public var isTextBlock: Bool {
        if case .text = self { return true }
        else { return false }
    }
    
    /// Create new Basic Code Block Definition
    /// - Parameters:
    ///   - basic: The opening sequence of characters of the code block
    ///   - closing: The closing sequence of characters of the code block
    public init(basic opening: String,
                closing: String = "") {
        self = .basic(opening: opening, closing: closing)
    }
    /// Create new Class Code Block Definition
    /// - Parameters:
    ///   - basic: The opening sequence of characters of the code block
    ///   - closing: The closing sequence of characters of the code block
    public init(`class` opening: String,
                closing: String = "") {
        self = .`class`(opening: opening, closing: closing)
    }
    /// Create new Global Code Block Definition
    /// - Parameters:
    ///   - basic: The opening sequence of characters of the code block
    ///   - closing: The closing sequence of characters of the code block
    public init(global opening: String,
                closing: String = "") {
        self = .global(opening: opening, closing: closing)
    }
    /// Create new Inline Code Block Definition
    /// - Parameters:
    ///   - basic: The opening sequence of characters of the code block
    ///   - closing: The closing sequence of characters of the code block
    public init(inline opening: String,
                closing: String = "") {
        self = .inline(opening: opening, closing: closing)
    }
    
    /// Create string that addes the lines from block to the generator method's output
    /// - Parameters:
    ///   - block: An array of lines of text to add the the generator method's output
    ///   - tabs: The number of tabs to insert
    /// - Returns: The resulting string to add to the content of the generator method
    private func strBlockToPrintCode(_ block: [String], tabs: Int) -> String {
        var rtn: String = ""
        
        let strTabs: String = "\t".repeated(tabs)
        
        for (index, line) in block.enumerated() {
            rtn += strTabs + "sourceBuilder += \"" + line.replacingOccurrences(of: "\\",
                                                                               with: "\\\\").replacingOccurrences(of: "\"",
                                                                                                                  with: "\\\"")
            if (index < block.count - 1) { rtn += "\\n" }
            rtn += "\""
            rtn += "\n"
        }
        
        
        return rtn
    }
    
    public func generateContent(block: DynamicSourceCodeBuilder.CodeBlockIdentifiers.CodeBlock,
                                source: String,
                                file: FSPath) throws -> GeneratedContent {
        // Changed from If Else statement to Switch to ensure each case gets processed
        // and compiler errors will occur if adding new block type case and forgetting to
        // add the processing of it here
        switch self {
            case .text:
                return GeneratedContent(generatorContent: strBlockToPrintCode(block.lines, tabs: 2))
            case .basic(opening: _, closing: _):
                return GeneratedContent(generatorContent: block.string + "\n")
            case .inline(opening: _, closing: _):
                return GeneratedContent(generatorContent: "\t\tsourceBuilder += \"\\(" + block.string + ")\"\n")
            case .`class`(opening: _, closing: _):
                return GeneratedContent(classContent: block.string + "\n")
            case .global(opening: _, closing: _):
                return GeneratedContent(globalContent: block.string + "\n")
            
        }
    }
}
/// Protocol defining a Code Block Tag Definition
/// Tag's body is not the direct content. They are attributes
/// The tag uses to then generate the content
public protocol TagBlockDefinition: CodeBlockDefinition {
    /// The name of the tag
    var name: String { get }
    
    /// Parse attributes to create a DSwiftTag
    /// - Parameters:
    ///    - attributes: The attributes of the Code Block Tag
    ///    - source: The source content string of the DSwift file
    ///    - path: The path to the file being processed
    ///    - tagRange: The range
    ///    - project:The Swift Project being worked on
    ///    - console: The object used to print to the console
    ///    - fileManager: The file manager to use when accessing the File System
    /// - Returns: Returns the parsed DSwiftTag or throws an exception if there was an error
    func parseTagProperties(attributes: [String: String],
                            source: String,
                            path: FSPath,
                            tagRange: Range<String.Index>,
                            project: SwiftProject,
                            console: Console,
                            using fileManager: FileManager) throws -> DSwiftTag
}

public extension TagBlockDefinition {
    /// Parse attributes to create a DSwiftTag
    /// - Parameters:
    ///    - attributes: The attributes of the Code Block Tag
    ///    - source: The source content string of the DSwift file
    ///    - path: The path to the file being processed
    ///    - tagRange: The range
    ///    - project:The Swift Project being worked on
    ///    - fileManager: The file manager to use when accessing the File System
    /// - Returns: Returns the parsed DSwiftTag or throws an exception if there was an error
    func parseTagProperties(attributes: [String: String],
                            source: String,
                            path: FSPath,
                            tagRange: Range<String.Index>,
                            project: SwiftProject,
                            using fileManager: FileManager) throws -> DSwiftTag {
        return try self.parseTagProperties(attributes: attributes,
                                           source: source,
                                           path: path,
                                           tagRange: tagRange,
                                           project: project,
                                           console: .null,
                                           using: fileManager)
    }
    
    /// Parse attributes to create a DSwiftTag
    /// - Parameters:
    ///    - attributes: The attributes of the Code Block Tag
    ///    - source: The source content string of the DSwift file
    ///    - path: The path to the file being processed
    ///    - tagRange: The range
    ///    - project:The Swift Project being worked on
    ///    - console: The object used to print to the console
    /// - Returns: Returns the parsed DSwiftTag or throws an exception if there was an error
    func parseTagProperties(attributes: [String: String],
                            source: String,
                            path: FSPath,
                            tagRange: Range<String.Index>,
                            project: SwiftProject,
                            console: Console) throws -> DSwiftTag {
        return try self.parseTagProperties(attributes: attributes,
                                           source: source,
                                           path: path,
                                           tagRange: tagRange,
                                           project: project,
                                           console: console,
                                           using: FileManager.default)
    }
    
    /// Parse attributes to create a DSwiftTag
    /// - Parameters:
    ///    - attributes: The attributes of the Code Block Tag
    ///    - source: The source content string of the DSwift file
    ///    - path: The path to the file being processed
    ///    - tagRange: The range
    ///    - project:The Swift Project being worked on
    /// - Returns: Returns the parsed DSwiftTag or throws an exception if there was an error
    func parseTagProperties(attributes: [String: String],
                            source: String,
                            path: FSPath,
                            tagRange: Range<String.Index>,
                            project: SwiftProject) throws -> DSwiftTag {
        return try self.parseTagProperties(attributes: attributes,
                                           source: source,
                                           path: path,
                                           tagRange: tagRange,
                                           project: project,
                                           console: .null,
                                           using: FileManager.default)
    }
}

public extension TagBlockDefinition {
    var openingBrace: String { return self.name }
    var closingBrace: String { return "" }
    
    var isTextBlock: Bool { return false }
    
    func generateContent(block: DynamicSourceCodeBuilder.CodeBlockIdentifiers.CodeBlock,
                         source: String,
                         file: FSPath) throws -> GeneratedContent {
        // Found include block when they should have been processed earlier
        let line = source.countOccurrences(of: "\n",
                                           inRange: source.startIndex..<block.range.lowerBound)
     
        throw DynamicSourceCodeBuilder.Errors.unprocessedTag(tag: self.name,
                                                             source: source,
                                                             in: file.string,
                                                             onLine: line + 1)
    }
}
/// Protocol defining a Tag Block that requires external resources
public protocol ExternalResourceTagBlockDefinition: TagBlockDefinition { }
/// Structure defining an Include Tag Block
public struct IncludeBlockDefinition: ExternalResourceTagBlockDefinition {
    public let name: String
    
    /// Create new Include Tag Block
    /// - Parameter name: The name of the block
    public init(name: String = "include") {
        self.name = name
    }
    
    public func parseTagProperties(attributes: [String: String],
                                   source: String,
                                   path: FSPath,
                                   tagRange: Range<String.Index>,
                                   project: SwiftProject,
                                   console: Console,
                                   using fileManager: FileManager) throws -> DSwiftTag {
        
        return .init(try DSwiftTag.Include.parseProperties(tagName: self.name,
                                                           attributes: attributes,
                                                           source: source,
                                                           path: path,
                                                           tagRange: tagRange,
                                                           project: project,
                                                           console: console,
                                                           using: fileManager),
                     tagRange: tagRange,
                     in: source)
    }
}
/// Structure defining a Reference Tag Block
public struct ReferenceBlockDefinition: ExternalResourceTagBlockDefinition {
    public let name: String
    
    /// Create new Include Tag Block
    /// - Parameter name: The name of the block
    public init(name: String = "reference") {
        self.name = name
    }
    
    public func parseTagProperties(attributes: [String: String],
                                   source: String,
                                   path: FSPath,
                                   tagRange: Range<String.Index>,
                                   project: SwiftProject,
                                   console: Console,
                                   using fileManager: FileManager) throws -> DSwiftTag {
        
        return .init(try DSwiftTag.Reference.parseProperties(tagName: self.name,
                                                             attributes: attributes,
                                                             source: source,
                                                             path: path,
                                                             tagRange: tagRange,
                                                             project: project,
                                                             console: console,
                                                             using: fileManager),
                          tagRange: tagRange,
                          in: source)
    }
}
