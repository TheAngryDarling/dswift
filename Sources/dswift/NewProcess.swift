//
//  NewProcess.swift
//  dswift
//
//  Created by Tyler Anger on 2021-09-03.
//

import Foundation

func newProcess() -> Process {
    let rtn = Process()
    
    if ProcessInfo.processInfo.environment.keys.contains("OS_ACTIVITY_DT_MODE") {
        var env = ProcessInfo.processInfo.environment
        env["OS_ACTIVITY_DT_MODE"] = nil
        rtn.environment = env
    }
    
    return rtn
}
