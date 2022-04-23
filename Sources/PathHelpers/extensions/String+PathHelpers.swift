//
//  File.swift
//  
//
//  Created by Tyler Anger on 2022-04-07.
//

import Foundation

public extension String {
    /// Get the path object for the given fs path
    var fsPath: FSPath {
        return FSPath(self)
    }
    var fsSafePath: FSSafePath {
        return FSSafePath(self)
    }
}
