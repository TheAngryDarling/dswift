//
//  URL+dswiftlib.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2019-07-21.
//

import Foundation
import SwiftPatches
import PathHelpers

extension URL {
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
