//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

#if !os(Linux)

// periphery:ignore:all - API

public import Foundation


extension ProcessInfo {
    /// Whether the app is currently running in a simulator environment.
    @inlinable public static var isRunningInSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
    
    /// Whether the app is currently being UI-Tested
    @inlinable public static var isBeingUITested: Bool {
        ProcessInfo.processInfo.environment["MHC_IS_BEING_UI_TESTED"] == "1"
    }
    
    /// Determines if a debgger is currently attached to the process.
    ///
    /// Source: https://stackoverflow.com/a/33177600
    @inlinable public static var isBeingDebugged: Bool {
        var info = kinfo_proc()
        var size = MemoryLayout.stride(ofValue: info)
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let junk = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        assert(junk == 0, "sysctl failed")
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
}

#endif
