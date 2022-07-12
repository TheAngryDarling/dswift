//
//  Array+dswiftlib.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2019-10-02.
//

import Foundation

internal extension Array where Element: CustomStringConvertible {
    /// Converts a String array into a single string that represents the string array.  Eg: '["XXX", "XXX", "XXX" ...]'
    func expressAsSingleLineString() -> String {
        var rtn: String = "["
        for (index, val) in self.enumerated() {
            if index > 0 { rtn += ", " }
            rtn += "\"\(val)\""
        }
        rtn += "]"
        return rtn
    }
}
