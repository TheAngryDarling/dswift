//
//  DynamicSourceCodeBuilder.swift
//  dswift
//
//  Created by Tyler Anger on 2018-12-05.
//

import Foundation

class DynamicSourceCodeBuilder {
    
    enum Errors: Error, CustomStringConvertible {
        case missingClosingBlock(closing: String, for: String, in: String, onLine: Int)
        case missingOpeningBlock(for: String, in: String, onLine: Int)
        
        public var description: String {
            switch self {
            case .missingClosingBlock(closing: let closing, for: let opening, in: let path, onLine: let line):
                return "\(path): Missing closing '\(closing)' for '\(opening)' starting on line \(line)"
            case .missingOpeningBlock(for: let closing, in: let path, onLine: let line):
                return "\(path): Missing opening block for '\(closing)' finishing on line \(line)"
            }
        }
    }
    
    enum CodeBlockDefinition {
        
        /// The opening brace of a code block
        var openingBrace: String {
            switch (self) {
            case .basic(let opening, _) : return opening
            case .static(let opening, _): return opening
            case .inline(let opening, _): return opening
            case .text: return ""
            }
        }
        
        /// The closing brace of a code block
        var closingBrace: String {
            switch (self) {
            case .basic(_, let closing) : return closing
            case .static(_, let closing): return closing
            case .inline(_, let closing): return closing
            case .text: return ""
            }
        }
        
        
        
        /// Indicator if the current code block is a basic block
        var isBasicBlock: Bool {
            if case .basic = self { return true }
            else { return false }
        }
        
        /// Indicator if the current code block is a static block
        var isStaticBlock: Bool {
            if case .static(_, _) = self { return true }
            else { return false }
        }
        
        /// Indicator if the current code block is an inline block
        var isInlineBlock: Bool {
            if case .inline = self { return true }
            else { return false }
        }
        /// Indicator if the current code block is a text block
        var isTextBlock: Bool {
            if case .text = self { return true }
            else { return false }
        }
        
        case basic(opening: String, closing: String)
        case `static`(opening: String, closing: String)
        case inline(opening: String, closing: String)
        case text
        
        init(basic: String, closing: String = "") {
            self = .basic(opening: basic, closing: closing)
        }
        init(`static`: String, closing: String = "") {
            self = .`static`(opening: `static`, closing: closing)
        }
        init(inline: String, closing: String = "") {
            self = .inline(opening: inline, closing: closing)
        }
    }
    
    struct CodeBlockIdentifiers {
        
        struct CodeBlock {
            let range: Range<String.Index>
            let type: CodeBlockDefinition
            let string: String
            
            var lines: [String] { return CodeBlock.splitBlockString(self.string) }
            
            let subBlockString: String?
            var subBlockLines: [String]? {
                guard let l = self.subBlockString else { return nil }
                return CodeBlock.splitBlockString(l)
            }
            
            public init(range: Range<String.Index>, type: CodeBlockDefinition, string: String, subBlockString: String? = nil) {
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
        }
        
        let opening: String
        let closing: String
        
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
        
        init(opening: String, closing: String, blocks: [CodeBlockDefinition]) {
            self.opening = opening
            self.closing = closing
            for b in blocks {
                if b.isTextBlock {
                    preconditionFailure("Do not provide CodeBlockDefinition.text in blocks array")
                }
            }
            //Make sure that the longest opening comes first
            self.blocks = blocks.sorted( by: { $0.openingBrace > $1.openingBrace } )
        }
        
        func nextBlockSet(from string: String, startingAt: String.Index, inFile file: String) throws -> CodeBlock? {
            //If we are at the end index, we are done
            guard startingAt !=  string.endIndex else { return nil }
            // Looks for opening block brace.  If not found we return the whole string as a text block
            let stBlockIndex: String.Index? = string.range(of: self.opening, range:startingAt..<string.endIndex)?.lowerBound
            
            if let closeBlockIndex: String.Index = string.range(of: self.closing, range:startingAt..<string.endIndex)?.lowerBound {
                if stBlockIndex == nil || closeBlockIndex < stBlockIndex! {
                    let line = string.countOccurrences(of: "\n",
                                                       inRange: string.startIndex..<closeBlockIndex)
                    throw Errors.missingOpeningBlock(for: self.closing, in: file, onLine: line + 1)
                }
            }
            
            guard let startBlockIndex = stBlockIndex else {
                return CodeBlock(range: startingAt..<string.endIndex,
                                 type: .text,
                                 string: String(string[startingAt..<string.endIndex]))
            }
            
            // Ensures that the opening of the block is at the starting index, otherwise we return a text block from startingAt to the beginning of the code block
            guard startBlockIndex == startingAt else {
                let str = String(string[startingAt..<startBlockIndex])
                return CodeBlock(range: startingAt..<startBlockIndex,
                                 type: .text,
                                 string: str)
            }
            
            let strMaxBlockIndicator: String.Index = string.index(startBlockIndex, offsetBy: self.maxOpeningBlockSize)
            let stringFrom: String = String(string[startBlockIndex..<strMaxBlockIndicator])
            
            for b in self.blocks {
                let op = self.opening + b.openingBrace
                if stringFrom.hasPrefix(op) {
                    let ed =  b.closingBrace + self.closing
                    guard let endBlockIndex: String.Index = string.range(of: ed, range:startBlockIndex..<string.endIndex)?.lowerBound else {
                        let line = string.countOccurrences(of: "\n",
                                                           inRange: string.startIndex..<startBlockIndex)
                        throw Errors.missingClosingBlock(closing: ed, for: op, in: file, onLine: line + 1)
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
    
    
    private var blockDefinitions: CodeBlockIdentifiers = CodeBlockIdentifiers(opening: "<%",
                                                                              closing: "%>",
                                                                              blocks: [CodeBlockDefinition(basic: ""),
                                                                                       CodeBlockDefinition(inline: "="),
                                                                                       CodeBlockDefinition(static: "!")/*,
                                                                                 CodeBlockDefinition(variable: "@")*/])
    
    
    private var source: String = ""
    private var file: String
    public private(set) var clsName: String
    public private(set) var sourceEncoding: String.Encoding
    private let dSwiftModuleName: String
    private let dSwiftURL: String
    
    public init(file: String, fileEncoding: String.Encoding? = nil, className: String, dSwiftModuleName: String, dSwiftURL: String) throws {
        self.file = file
        if let enc = fileEncoding {
            verbosePrint("Reading file '\(file.lastPathComponent)' with encoding \(enc)")
            self.source = try String(contentsOfFile: self.file, encoding: enc)
            self.sourceEncoding = enc
        } else {
             verbosePrint("Reading file '\(file.lastPathComponent)' with unknown encoding")
            var enc: String.Encoding = String.Encoding.utf8
            self.source = try String(contentsOfFile: self.file, foundEncoding: &enc)
            self.sourceEncoding = enc
        }
       
        self.clsName = className
        self.dSwiftModuleName = dSwiftModuleName
        self.dSwiftURL = dSwiftURL
    }
    
    func strBlockToPrintCode(_ block: [String], tabs: Int) -> String {
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
    
    func generateSourceGenerator() throws -> String {
        var generatorContent: String = ""
        var classContent: String = ""
        var lastBlockEnding: String.Index = self.source.startIndex
        var lastBlock: CodeBlockIdentifiers.CodeBlock? = nil
        while let block = try blockDefinitions.nextBlockSet(from: self.source,
                                                            startingAt: lastBlockEnding,
                                                            inFile: self.file) {
            lastBlockEnding = block.range.upperBound
            /*if let lb = lastBlock, !block.type.isInlineBlock {
                if generatorContent.hasPrefix("\n")
            }*/
            if block.type.isTextBlock { // Plain text
                var lines = block.lines
                if lines.first == "" && (lastBlock?.type.isBasicBlock ?? false) {
                    lines.removeFirst()
                }
                generatorContent += strBlockToPrintCode(lines, tabs: 2)
            } else if block.type.isBasicBlock { // ?%...%?
                generatorContent += block.string + "\n"
            } else if block.type.isInlineBlock { // ?%=..%?
                generatorContent += "\t\tsourceBuilder += \"\\(" + block.string + ")\"\n"
            } else if block.type.isStaticBlock {
                classContent += block.string + "\n"
            }
            
            lastBlock = block
        }
        var completeSource: String = "import Foundation\n\n"
        completeSource += "public class \(clsName): NSObject {\n\n"
        completeSource += "\tpublic override var description: String { return generate() }\n\n"
        completeSource += classContent
        completeSource += "\n\tpublic func generate() -> String {\n"
        completeSource += "\t\tvar sourceBuilder: String = \"\"\n\n"
        
        completeSource += "\t\tsourceBuilder += \"//  This file was dynamically generated from '\(self.file.lastPathComponent)' by \(dSwiftModuleName).  Please do not modify directly.\\n\"\n"
        completeSource += "\t\tsourceBuilder += \"//  \(dSwiftModuleName) can be found at \(dSwiftURL).\\n\\n\"\n"
        completeSource += generatorContent
        completeSource += "\n\t\treturn sourceBuilder\n"
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
