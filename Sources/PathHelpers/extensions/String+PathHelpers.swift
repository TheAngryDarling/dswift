//
//  File.swift
//  
//
//  Created by Tyler Anger on 2022-04-07.
//

import Foundation

public extension String {
    init(contentsOf path: FSPath,
         encoding: String.Encoding,
         using fileManager: FileManager) throws {
        try self.init(contentsOf: path.url, encoding: encoding)
    }
    init(contentsOf path: FSPath,
         foundEncoding encoding: inout String.Encoding,
         using fileManager: FileManager) throws {
        try self.init(contentsOf: path.url, usedEncoding: &encoding)
    }
    func write(to path: FSPath,
               atomically: Bool,
               encoding: String.Encoding,
               using fileManager: FileManager) throws {
        try self.write(to: path.url,
                       atomically: atomically,
                       encoding: encoding)
    }
}
