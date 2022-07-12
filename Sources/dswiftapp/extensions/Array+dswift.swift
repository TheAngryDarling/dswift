//
//  Array+dswift.swift
//  dswift
//
//  Created by Tyler Anger on 2022-03-22.
//

import Foundation
import XcodeProj

internal extension Array where Element == XcodeTarget {
    /// Returns the target with the given name.  If not target matches the given name nil will be returned
    subscript(name: String) -> XcodeTarget? {
        for target in self {
            if target.name == name {
                return target
            }
        }
        return nil
    }
}
