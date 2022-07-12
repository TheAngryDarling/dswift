//
//  Dictionary+dswiftlib.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2022-01-18.
//

import Foundation

internal extension Dictionary where Key: CustomStringConvertible, Value: CustomStringConvertible {
    /// Converts a Dictionary into a single string that represents the Dictionary.  Eg: '["XXX": "YYYY", "XXX": "YYYY", "XXX": "YYYY" ...]'
    func expressAsSingleLineString() -> String {
        var rtn: String = "["
        for (index, val) in self.enumerated() {
            if index > 0 { rtn += ", " }
            rtn += "\"\(val.0)\": \"\(val.1)\""
        }
        rtn += "]"
        return rtn
    }
}
