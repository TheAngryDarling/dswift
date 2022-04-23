//
//  Array+dswiftlib.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2019-10-02.
//

import Foundation

internal extension Array where Element == String {
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

internal extension Array {
    /// Finds the first element that returns a result from the predicate
    /// - Parameter predicate: The closure to call passing each element
    /// - Returns: Returns a valid response from predicate or nil if no element produces a response from predicate
    func firstResponse<R>(from predicate: (Element) throws -> R?) rethrows -> R? {
        for e in self {
            if let r = try predicate(e) {
                return r
            }
        }
        return nil
    }
}
