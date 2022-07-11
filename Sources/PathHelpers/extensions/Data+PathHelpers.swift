//
//  Data+PathHelpers.swift
//  
//
//  Created by Tyler Anger on 2022-04-25.
//

import Foundation

public extension Data {
    init(contentsOf path: FSPath,
         using fileManager: FileManager) throws {
        self = try Data.init(contentsOf: path.url)
    }
}
