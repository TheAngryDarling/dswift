//
//  GitIgnore.swift
//  dswift
//
//  Created by Tyler Anger on 2020-07-24.
//

import Foundation
import BasicCodableHelpers

/// Structuer containing the contents of a gitignore file
public final class GitIgnoreFile {
    // Line Item
    public enum Item {
        /// Comment line
        case comment(String)
        /// Ignore path
        case rule(String)
        
        public var isComment: Bool {
            guard case .comment(_) = self else {
                return false
            }
            return true
        }
        
        /// The String content of a line item
        public var contents: String {
            switch self {
                case .comment(let line): return "#" + line
                case .rule(let line): return line
            }
        }
        
        public init(_ contents: String) {
            if contents.hasPrefix("#") {
                var val = contents
                val.removeFirst()
                self = .comment(val)
            } else {
                self = .rule(contents)
            }
        }
    }
    /// Strucuter of a comment defined git sub section
    public final class SubSection {
        /// The name of the sub section
        public var name: String
        /// Line items in the sub section
        public var items: [Item] = []
        /// The String content of a sub section
        public var contents: String {
            var rtn: String = ""
            if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                rtn += "## " + name.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            }
            for item in items {
                rtn += item.contents + "\n"
            }
            
            return rtn
        }
        
        public init(name: String) {
            self.name = name
        }
    }
    /// Structuer of a comment defined git section
    public final class Section {
        /// Name of the section
        public var name: String
        /// Description of the section
        public var description: [String]
        /// List of sub sections
        public var subSections: [SubSection] = []
        /// Line items in the section
        public var items: [Item] = []
        /// The String content of a section
        public var contents: String {
            var rtn: String = ""
            if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                rtn += "# " + name.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
                if self.description.count > 0 {
                    rtn += "#\n"
                }
            }
            for line in self.description {
                rtn += "# " + line + "\n"
            }
            
            if self.items.count > 0 { rtn += "\n" }
            for item in items {
                rtn += item.contents + "\n"
            }
            if self.subSections.count > 0 { rtn += "\n" }
            for subSection in self.subSections {
                rtn += subSection.contents + "\n"
            }
            
            return rtn
        }
        
        public init(name: String = "", description: [String] = []) {
            self.name = name
            self.description = description
        }
        
        public init(name: String, description: String) {
            self.name = name
            self.description = description.split(separator: "\n").map(String.init)
        }
    }
    /// List of sections
    public var sections: [Section]
    /// Line items in the file that aren't under any section/sub section
    public var items: [Item]
    /// The encoding of the file
    private var encoding: String.Encoding = .utf8
    /// The String content of a file
    public var contents: String {
        var rtn: String = ""
        var hasPrintedOther: Bool = false
        for section in self.sections {
            rtn += section.contents
            if section.name == "Other" {
                hasPrintedOther = true
                for item in items {
                    rtn += item.contents + "\n"
                }
            }
            rtn += "\n"
        }
        if !hasPrintedOther {
            if self.items.count > 0 {
                if self.sections.count > 0 {
                    rtn += "\n"
                    rtn += "# Other\n\n"
                }
                for item in items {
                    rtn += item.contents + "\n"
                }
            }
        }
        
        return rtn
        
    }
    
    public init() {
        self.sections = []
        self.items = []
    }
    
    public init(atPath path: String) throws {
        self.sections = []
        self.items = []
        try self.open(atPath: path)
    }
    /// Creates a new structure of gitignore.
    /// If the path exists then it will be parsed
    public func open(atPath path: String) throws {
        let path = NSString(string: path).expandingTildeInPath
        if FileManager.default.fileExists(atPath: path) {
            let content = try String(contentsOfFile: path, foundEncoding: &self.encoding)
            let lines = content.split(separator: "\n").map(String.init)
            var currentSection: Section? = nil
            var currentSubSection: SubSection? = nil
            var idx: Int = 0
            while idx < lines.count {
                guard !lines[idx].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    idx += 1
                    continue
                }
                if lines[idx].hasPrefix("# ") {
                    
                    let name = lines[idx].suffix(from: lines[idx].index(lines[idx].startIndex, offsetBy: 2))
                    var description: [String] = []
                    idx += 1
                    // Skip seperator line
                    if lines[idx].trimmingCharacters(in: .whitespacesAndNewlines) == "#" { idx += 1 }
                    
                    while lines[idx].hasPrefix("# ") {
                        let ln = lines[idx].suffix(from: lines[idx].index(lines[idx].startIndex, offsetBy: 2))
                        idx += 1
                        description.append(String(ln))
                    }
                    let sec = Section(name: String(name), description: description)
                    self.sections.append(sec)
                    currentSection = sec
                    currentSubSection = nil
                    
                } else if lines[idx].hasPrefix("## ") {
                    
                    let name = lines[idx].suffix(from: lines[idx].index(lines[idx].startIndex, offsetBy: 3))
                    idx += 1
                    let subSec = SubSection(name: String(name))
                    if let sec = currentSection {
                        sec.subSections.append(subSec)
                    } else {
                        currentSection = Section()
                        self.sections.append(currentSection!)
                        currentSection!.subSections.append(subSec)
                    }
                    currentSubSection = subSec
                    
                } else {
                    let item = Item(lines[idx])
                    
                    if let subSec = currentSubSection {
                        subSec.items.append(item)
                    } else if let sec = currentSection {
                        sec.items.append(item)
                    } else {
                        self.items.append(item)
                    }
                    idx += 1
                }
            }
        }
    }
    /// Save the file
    public func save(to path: String) throws {
        try self.contents.write(toFile: path, atomically: true, encoding: self.encoding)
    }
}

extension GitIgnoreFile: CustomStringConvertible {
    public var description: String {
        return self.contents
    }
}

public extension GitIgnoreFile.SubSection {
    /// Tries to find the given value
    func contains(_ value: String) -> Bool {
        for item in self.items {
            if (item.contents == value) { return true }
        }
        return false
    }
    
    @discardableResult
    func addItem(_ value: GitIgnoreFile.Item) -> GitIgnoreFile.SubSection {
        self.items.append(value)
        return self
    }
    @discardableResult
    func addComment(_ value: String) -> GitIgnoreFile.SubSection {
        return self.addItem(.comment(value))
    }
    @discardableResult
    func addRule(_ value: String) -> GitIgnoreFile.SubSection {
        return self.addItem(.rule(value))
    }
}
public extension GitIgnoreFile.Section {
    
    func find(_ name: String) -> GitIgnoreFile.SubSection? {
        guard let rtn = self.subSections.first(where: { $0.name == name}) else {
            return nil
        }
        return rtn
    }
    
    subscript(name: String) -> GitIgnoreFile.SubSection {
        guard let rtn = self.find(name) else {
            return addSubSection(name: name)
        }
        return rtn
    }
    
    
    /// Tries to find the given value
    /// If deepLook is set to true, this will look within child objects
    func contains(_ value: String, deepLook: Bool = true) -> Bool {
        for item in self.items {
            if (item.contents == value) { return true }
        }
        if deepLook {
            for subSection in self.subSections {
                if subSection.contains(value) { return true }
            }
        }
        return false
    }
    
    func addSubSection(name: String) -> GitIgnoreFile.SubSection {
        let subsection = GitIgnoreFile.SubSection(name: name)
        self.subSections.append(subsection)
        return subsection
    }
    
    @discardableResult
    func addItem(_ value: GitIgnoreFile.Item) -> GitIgnoreFile.Section {
        self.items.append(value)
        return self
    }
    @discardableResult
    func addComment(_ value: String) -> GitIgnoreFile.Section {
        return self.addItem(.comment(value))
    }
    @discardableResult
    func addRule(_ value: String) -> GitIgnoreFile.Section {
        return self.addItem(.rule(value))
    }
}
public extension GitIgnoreFile {
    
    
    func find(_ name: String) -> GitIgnoreFile.Section? {
        guard let rtn = self.sections.first(where: { $0.name == name}) else {
            return nil
        }
        return rtn
    }
    
    subscript(name: String) -> GitIgnoreFile.Section {
        guard let rtn = self.find(name) else {
            return addSection(name: name)
        }
        return rtn
    }
    
    /// Tries to find the given value
    /// If deepLook is set to true, this will look within child objects
    func contains(_ value: String, deepLook: Bool = true) -> Bool {
        for item in self.items {
            if (item.contents == value) { return true }
        }
        if deepLook {
            for section in self.sections {
                if section.contains(value, deepLook: deepLook) { return true }
            }
        }
        return false
    }
    
    func addSection(name: String, description: String = "") -> GitIgnoreFile.Section {
        let section = GitIgnoreFile.Section(name: name, description: description)
        self.sections.append(section)
        return section
    }
    
    func addSection(name: String, description: [String]) -> GitIgnoreFile.Section {
        let section = GitIgnoreFile.Section(name: name, description: description)
        self.sections.append(section)
        return section
    }
    
    @discardableResult
    func addItem(_ value: GitIgnoreFile.Item) -> GitIgnoreFile {
        self.items.append(value)
        return self
    }
    @discardableResult
    func addComment(_ value: String) -> GitIgnoreFile {
        return self.addItem(.comment(value))
    }
    @discardableResult
    func addRule(_ value: String) -> GitIgnoreFile {
        return self.addItem(.rule(value))
    }

    static var standardFile: GitIgnoreFile {
        let rtn = GitIgnoreFile()
        rtn.addSection(name: "Xcode", description: "Common Xcode Ignore Rules")
            .addSubSection(name: "Build")
            .addRule("/build")
            .addRule("/DerivedData")
            .addRule("/*.xcodeproj")
        rtn["Xcode"].addSubSection(name: "Various Settings")
            .addRule("xcuserdata/")
        
        rtn.addSection(name: "Swift Package Manager",
                       description: "Common Swift Package Manager Ignore Rules")
            .addRule("Package.resolved")
            .addRule("/.build")
            .addRule("/Packages")
        
        rtn.addSection(name: "CocoaPods",
                       description: ["We recommend against adding the Pods directory to your .gitignore.",
                                     " However you should judge for yourself, the pros and cons are mentioned at:",
                                     "https://guides.cocoapods.org/using/using-cocoapods.html#should-i-check-the-pods-directory-into-source-control"])
            .addComment("/Pods")
        rtn.addSection(name: "Carthage",
                    description: "Add this line if you want to avoid checking in source code from Carthage dependencies.")
            .addComment("Carthage/Checkouts")
            .addComment("Carthage/Build")
        rtn.addSection(name: "Other")
            .addRule(".DS_Store")
        return rtn
    }
    
    static var `default`: GitIgnoreFile {
        return settings.defaultGitIgnore ?? .standardFile
    }
    
}

public func +(lhs: GitIgnoreFile, rhs: GitIgnoreFile) -> GitIgnoreFile {
    let rtn = GitIgnoreFile()
    for item in lhs.items {
        rtn.items.append(item)
    }
    for section in lhs.sections {
        let newSection = rtn.addSection(name: section.name, description: section.description)
        for item in section.items {
            newSection.items.append(item)
        }
        for subSection in section.subSections {
            let newSubSection = newSection.addSubSection(name: subSection.name)
            for item in subSection.items {
                newSubSection.items.append(item)
            }
        }
    }
    for item in rhs.items {
        guard !item.isComment else { continue }
        guard !rtn.contains(item.contents, deepLook: true) else { continue }
        rtn.items.append(item)
    }
    for section in rhs.sections {
        var addSection: Bool = false
        let newSection = rtn.find(section.name) ?? { () -> GitIgnoreFile.Section in
            addSection = true
            return GitIgnoreFile.Section(name: section.name, description: section.description)
        }()
        
        if !addSection && newSection.description.count == 0 && section.description.count > 0 {
            // Copy description from rhs if there isn't one on the lhs
            newSection.description = section.description
        }
        
        for subSection in section.subSections {
            var addSubSection: Bool = false
            let newSubSection = newSection.find(subSection.name) ?? { () -> GitIgnoreFile.SubSection in
                addSubSection = true
                return GitIgnoreFile.SubSection(name: section.name)
            }()
            
            for item in subSection.items {
                guard !item.isComment else { continue }
                guard !rtn.contains(item.contents, deepLook: true) else { continue }
                newSubSection.items.append(item)
            }
            if newSubSection.items.count > 0 && addSubSection {
                newSection.subSections.append(newSubSection)
            }
        }
        
        for item in section.items {
            guard !item.isComment else { continue }
            guard !rtn.contains(item.contents, deepLook: true) else { continue }
            newSection.items.append(item)
        }
        
        if (newSection.items.count > 0 || newSection.subSections.count > 0) && addSection {
            rtn.sections.append(newSection)
        }
    }
    return rtn
}

public func +=(lhs: inout GitIgnoreFile, rhs: GitIgnoreFile) {
    lhs = lhs + rhs
}

extension GitIgnoreFile.Item: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self.init(value)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.contents)
    }
}

extension GitIgnoreFile.SubSection: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case items
    }
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: try container.decode(String.self, forKey: .name))
        self.items = try container.decodeIfPresent([GitIgnoreFile.Item].self,
                                                   forKey: .items,
                                                   withDefaultValue: Array<GitIgnoreFile.Item>())
    }
       
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encodeIfNotEmpty(self.items, forKey: .items)
    }
}

extension GitIgnoreFile.Section: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case items
        case subsections
    }
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: try container.decode(String.self, forKey: .name),
                  description: try container.decode([String].self, forKey: .description))
        self.items = try container.decodeIfPresent([GitIgnoreFile.Item].self,
                                                   forKey: .items,
                                                   withDefaultValue: Array<GitIgnoreFile.Item>())
        self.subSections = try container.decodeIfPresent([GitIgnoreFile.SubSection].self,
                                                         forKey: .subsections,
                                                         withDefaultValue: Array<GitIgnoreFile.SubSection>())
    }
       
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.description, forKey: .description)
        try container.encodeIfNotEmpty(self.items, forKey: .items)
        try container.encodeIfNotEmpty(self.subSections, forKey: .subsections)
    }
}

extension GitIgnoreFile: Codable {
    enum CodingKeys: String, CodingKey {
       case sections
       case items
    }
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        self.items = try container.decodeIfPresent([GitIgnoreFile.Item].self,
                                                   forKey: .items,
                                                   withDefaultValue: Array<GitIgnoreFile.Item>())
        self.sections = try container.decodeIfPresent([GitIgnoreFile.Section].self,
                                                      forKey: .sections,
                                                      withDefaultValue: Array<GitIgnoreFile.Section>())
    }
      
    public func encode(to encoder: Encoder) throws {
       var container = encoder.container(keyedBy: CodingKeys.self)
       try container.encodeIfNotEmpty(self.items, forKey: .items)
       try container.encodeIfNotEmpty(self.sections, forKey: .sections)
    }
}
