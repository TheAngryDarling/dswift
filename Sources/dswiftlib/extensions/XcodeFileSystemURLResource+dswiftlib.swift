//
//  XcodeFileSystemURLResource+dswiftlib.swift
//  
//
//  Created by Tyler Anger on 2022-04-25.
//

import Foundation
import PathHelpers
import XcodeProj

internal extension XcodeFileSystemURLResource {
    init(file path: FSPath) {
        self.init(file: path.string)
    }
}
