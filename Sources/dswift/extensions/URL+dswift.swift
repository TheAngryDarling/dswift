//
//  URL+dswift.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-21.
//

import Foundation
import SwiftPatches

extension URL {
    /// Returns if current url is a path directory
    var isPathDirectory: Bool {
        var isDir: Bool = false
        guard FileManager.default.fileExists(atPath: self.path, isDirectory: &isDir) else { return false }
        return isDir
    }
    /// Returns if the current url is a path file
    var isPathFile: Bool {
        var isDir: Bool = true
        guard FileManager.default.fileExists(atPath: self.path, isDirectory: &isDir) else { return false }
        return !isDir
    }
    /// Returns the path modification date if available
    var pathModificationDate: Date? {
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: self.path)
            return attr[FileAttributeKey.modificationDate] as? Date
        } catch {
            return nil
        }
    }
    
    /// Returns the path creation date if available
    var pathCreationDate: Date? {
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: self.path)
            return attr[FileAttributeKey.creationDate] as? Date
        } catch {
            return nil
        }
    }
    
    /// Creates a new URL that is relative to the one given
    ///
    /// - Parameter url: The url to be relative from
    /// - Returns: A new URL that is relative to the one provided
    func relative(to url: URL) -> URL {
        
        guard self.scheme == url.scheme &&
            self.host == url.host &&
            self.port == url.port else {
                return self
        }
        
        
        let _self = self.standardized
        let _url = url.standardized
        
        /*if _self.isFileURL {
         // Fix any .., . paths
         _self.standardize()
         _url.standardize()
         }*/
        
        
        let destComponents = _self.pathComponents
        let baseComponents = _url.pathComponents
        
        var i = 0
        while i < destComponents.count && i < baseComponents.count
            && destComponents[i] == baseComponents[i] {
                i += 1
        }
        
        // Build relative path:
        var relComponents = Array(repeating: "..", count: baseComponents.count - i)
        relComponents.append(contentsOf: destComponents[i...])
        
        var path = relComponents.joined(separator: "/")
        if let s = _self.query {
            path += "?" + s
        }
        
        return URL(string: path)!
    }
    
    
}
