//
//  GitIgnore.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2020-07-24.
//

import Foundation
import BasicCodableHelpers

/// Structure containing the contents of a gitignore file
public final class GitIgnoreFile {
    #if os(Windows)
    fileprivate static let newLine: String = "\r\n"
    #else
    fileprivate static let newLine: String = "\n"
    #endif
    // Line Item
    public enum Item {
        /// Comment line
        case comment(String)
        /// Ignore path
        case rule(String)
        /// Indicator if this item is a comment or not
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
        /// Create new GitIgnore Item
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
                rtn += "## " + name.trimmingCharacters(in: .whitespacesAndNewlines) + GitIgnoreFile.newLine
            }
            for item in items {
                rtn += item.contents + GitIgnoreFile.newLine
            }
            
            return rtn
        }
        /// Create new GitIgnore SubSection
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
                rtn += "# " + name.trimmingCharacters(in: .whitespacesAndNewlines) + GitIgnoreFile.newLine
                if self.description.count > 0 {
                    rtn += "#" + GitIgnoreFile.newLine
                }
            }
            for line in self.description {
                rtn += "# " + line + GitIgnoreFile.newLine
            }
            
            if self.items.count > 0 { rtn += GitIgnoreFile.newLine }
            for item in items {
                rtn += item.contents + GitIgnoreFile.newLine
            }
            if self.subSections.count > 0 { rtn += GitIgnoreFile.newLine }
            for subSection in self.subSections {
                rtn += subSection.contents + GitIgnoreFile.newLine
            }
            
            return rtn
        }
        
        /// Create new GitIgnore Section
        /// - Parameters:
        ///   - name: Section Name
        ///   - description: Description lines of the section
        public init(name: String = "",
                    description: [String] = []) {
            self.name = name
            self.description = description
        }
        /// Create new GitIgnore Section
        /// - Parameters:
        ///   - name: Section Name
        ///   - description: Description lines of the section
        public init(name: String,
                    description: String) {
            self.name = name
            
            self.description = description.replacingOccurrences(of: "\r\n",
                                                                with: "\n")
                .split(separator: "\n")
                .map(String.init)
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
                    rtn += item.contents + GitIgnoreFile.newLine
                }
            }
            rtn += GitIgnoreFile.newLine
        }
        if !hasPrintedOther {
            if self.items.count > 0 {
                if self.sections.count > 0 {
                    rtn += GitIgnoreFile.newLine
                    rtn += "# Other" + GitIgnoreFile.newLine + GitIgnoreFile.newLine
                }
                for item in items {
                    rtn += item.contents + GitIgnoreFile.newLine
                }
            }
        }
        
        return rtn
        
    }
    
    public init() {
        self.sections = []
        self.items = []
    }
    
    /// Opens up a GitIgnore file at the given path
    /// - Parameter path: The path to the GitIgnore file to open
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
            let lines = content.replacingOccurrences(of: "\r\n",
                                                     with: "\n")
                .split(separator: "\n")
                .map(String.init)
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
        return self.items.contains(where: { return $0.contents == value })
    }
    
    /// Add new Item to the GitIgnore SubSection and return same GitIgnore SubSection
    /// - Parameter value: The Item to add
    /// - Returns: Returns the same GitIgnore SubSection
    @discardableResult
    func addItem(_ value: GitIgnoreFile.Item) -> GitIgnoreFile.SubSection {
        self.items.append(value)
        return self
    }
    /// Add new comment to the GitIgnore SubSection and return same GitIgnore SubSection
    /// - Parameter value: The comment to add
    /// - Returns: Returns the same GitIgnore SubSection
    @discardableResult
    func addComment(_ value: String) -> GitIgnoreFile.SubSection {
        return self.addItem(.comment(value))
    }
    /// Add new Rule to the GitIgnore SubSection and return same GitIgnore SubSection
    /// - Parameter value: The Item to add
    /// - Returns: Returns the same GitIgnore SubSection
    @discardableResult
    func addRule(_ value: String) -> GitIgnoreFile.SubSection {
        return self.addItem(.rule(value))
    }
}
public extension GitIgnoreFile.Section {
    
    /// Find a GitIgnore SubSection with the given name
    /// - Parameter name: The name of the SubSection to find
    /// - Returns: Returns the found SubSection or nil if not found
    func find(_ name: String) -> GitIgnoreFile.SubSection? {
        guard let rtn = self.subSections.first(where: { $0.name == name}) else {
            return nil
        }
        return rtn
    }
    
    /// Get the GItIgnore SubSection with the giveen name
    /// - Parameter name: The name of the SubSection to get
    /// - Returns: Returns the SubSection with the given name.  If SubSection does not exists one will be created
    subscript(name: String) -> GitIgnoreFile.SubSection {
        guard let rtn = self.find(name) else {
            return addSubSection(name: name)
        }
        return rtn
    }
    
    
    /// Tries to find the given value
    /// If deepLook is set to true, this will look within child objects
    func contains(_ value: String, deepLook: Bool = true) -> Bool {
        if self.items.contains(where: { return $0.contents == value }) {
            return true
        }
        if deepLook {
            return self.subSections.contains(where: { return $0.contains(value) })
        }
        return false
    }
    
    /// Creates new GitIgnore SubSection and returns the new SubSection
    /// - Parameter name: Name of the SubSection to create
    /// - Returns: Returns the new SubSection
    func addSubSection(name: String) -> GitIgnoreFile.SubSection {
        let subsection = GitIgnoreFile.SubSection(name: name)
        self.subSections.append(subsection)
        return subsection
    }
    
    /// Add new Item to the GitIgnore Section and return same GitIgnore Section
    /// - Parameter value: The Item to add
    /// - Returns: Returns the same GitIgnore Section
    @discardableResult
    func addItem(_ value: GitIgnoreFile.Item) -> GitIgnoreFile.Section {
        self.items.append(value)
        return self
    }
    /// Add new Comment to the GitIgnore Section and return same GitIgnore Section
    /// - Parameter value: The comment to add
    /// - Returns: Returns the same GitIgnore Section
    @discardableResult
    func addComment(_ value: String) -> GitIgnoreFile.Section {
        return self.addItem(.comment(value))
    }
    /// Add new Rule to the GitIgnore Section and return same GitIgnore Section
    /// - Parameter value: The rule to add
    /// - Returns: Returns the same GitIgnore Section
    @discardableResult
    func addRule(_ value: String) -> GitIgnoreFile.Section {
        return self.addItem(.rule(value))
    }
}
public extension GitIgnoreFile {
    
    
    /// Find a section with the given name
    /// - Parameter name: The name of the section to look for
    /// - Returns: Returns the found section or nil if not found
    func find(_ name: String) -> GitIgnoreFile.Section? {
        guard let rtn = self.sections.first(where: { $0.name == name}) else {
            return nil
        }
        return rtn
    }
    
    /// Finds or creates the section provided by the name
    subscript(name: String) -> GitIgnoreFile.Section {
        guard let rtn = self.find(name) else {
            return addSection(name: name)
        }
        return rtn
    }
    
    /// Tries to find the given value
    /// If deepLook is set to true, this will look within child objects
    /// - Parameters:
    ///   - value: The value to look for
    ///   - deepLook: Indicator if should look in sections and sub sections
    /// - Returns: Returns a bool indicator if the value was found
    func contains(_ value: String, deepLook: Bool = true) -> Bool {
        if self.items.contains(where: { return $0.contents == value }) {
            return true
        }
        if deepLook {
            return self.sections.contains(where: { return $0.contains(value,
                                                                         deepLook: true) })
        }
        return false
    }
    
    /// Add a new section to the GitIgnore File then return the instance to the new section
    /// - Parameters:
    ///   - name: The name of the new section
    ///   - description: The Descripition of the section
    /// - Returns: Returns the newly created section
    @discardableResult
    func addSection(name: String, description: String = "") -> GitIgnoreFile.Section {
        let section = GitIgnoreFile.Section(name: name, description: description)
        self.sections.append(section)
        return section
    }
    
    /// Add a new section to the GitIgnore File then return the instance to the new section
    /// - Parameters:
    ///   - name: The name of the new section
    ///   - description: The Descripition (Array of Lines) of the section
    /// - Returns: Returns the newly created section
    @discardableResult
    func addSection(name: String, description: [String]) -> GitIgnoreFile.Section {
        let section = GitIgnoreFile.Section(name: name, description: description)
        self.sections.append(section)
        return section
    }
    
    /// Add new GitIgnore Item to GitIgnore File and return same GitIgnoreFile
    /// - Parameter value: The item to add
    /// - Returns: Returns the same GitIgnore File
    @discardableResult
    func addItem(_ value: GitIgnoreFile.Item) -> GitIgnoreFile {
        self.items.append(value)
        return self
    }
    /// Add new comment to GitIgnore File and return same GitIgnoreFile
    /// - Parameter value: The comment to add
    /// - Returns: Returns the same GitIgnore File
    @discardableResult
    func addComment(_ value: String) -> GitIgnoreFile {
        return self.addItem(.comment(value))
    }
    
    /// Add new rule to GitIgnore File and return same GitIgnoreFile
    /// - Parameter value: The rule toadd
    /// - Returns: Returns the same GitIgnore File
    @discardableResult
    func addRule(_ value: String) -> GitIgnoreFile {
        return self.addItem(.rule(value))
    }

    /// The Standard GitIgnore file content
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
            .addRule("/.swiftpm")
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
    /// The default GitIgnore content
    static var `default`: GitIgnoreFile {
        return .standardFile
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

extension GitIgnoreFile.Item: Equatable {
    public static func ==(lhs: GitIgnoreFile.Item,
                          rhs: GitIgnoreFile.Item) -> Bool {
        switch (lhs, rhs) {
            case (.comment(let lhsV), .comment(let rhsV)):
                return lhsV == rhsV
            case (.rule(let lhsV), .rule(let rhsV)):
                return lhsV == rhsV
            default: return false
        }
    }
}

extension GitIgnoreFile.SubSection: Equatable {
    public static func ==(lhs: GitIgnoreFile.SubSection,
                          rhs: GitIgnoreFile.SubSection) -> Bool {
        return lhs.name == rhs.name &&
               lhs.items.elementsEqual(rhs.items)
    }
}


extension GitIgnoreFile.Section: Equatable {
    public static func ==(lhs: GitIgnoreFile.Section,
                          rhs: GitIgnoreFile.Section) -> Bool {
        return lhs.name == rhs.name &&
               lhs.description.elementsEqual(rhs.description) &&
               lhs.subSections.elementsEqual(rhs.subSections) &&
               lhs.items.elementsEqual(rhs.items)
    }
}

extension GitIgnoreFile: Equatable {
    public static func ==(lhs: GitIgnoreFile,
                          rhs: GitIgnoreFile) -> Bool {
        return lhs.sections.elementsEqual(rhs.sections) &&
               lhs.items.elementsEqual(rhs.items) &&
               lhs.encoding == rhs.encoding
    }
}
