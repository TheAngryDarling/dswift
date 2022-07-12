//
//  File.swift
//  
//
//  Created by Tyler Anger on 2022-05-10.
//

import Foundation
import VersionKit

internal extension Version.SingleVersion {
    var fullDescription: String {
        var rtn: String = "\(self.major).\(self.minor ?? 0).\(self.revision ?? 0)"
        if let bn = self.buildNumber, bn > 0 { rtn += ".\(bn)" }
        for pre in self.prerelease { rtn += "-" + pre }
        for bld in self.build { rtn += "+" + bld }
        //if let b = self.build { rtn += "-\(b)" }
        return rtn
    }
}
