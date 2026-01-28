//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// periphery:ignore:all - API

#if canImport(AVFoundation) && os(iOS)
private import AVFoundation
public import Foundation


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
