//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// periphery:ignore:all - API

private import AVFoundation
public import Darwin
public import Foundation
import MachO


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


extension ProcessInfo {
    /// The app's current amount of resident memory.
    @inlinable public static var residentMemory: UInt64 {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / mach_msg_type_number_t(MemoryLayout<natural_t>.size)
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kerr == KERN_SUCCESS ? taskInfo.resident_size / 1024 / 1024 : 0
    }
    
    /// The app's current memory footprint.
    @inlinable public static var memoryFootprint: UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size) / mach_msg_type_number_t(MemoryLayout<integer_t>.size)
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return kerr == KERN_SUCCESS ? info.phys_footprint / 1024 / 1024 : 0
    }
}


#if os(iOS)
extension ProcessInfo {
    /// Whether the iPhone the app currently is running on is a "Pro" model.
    public static let isProDevice: Bool = {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )
        return !session.devices.isEmpty
    }()
}
#endif
