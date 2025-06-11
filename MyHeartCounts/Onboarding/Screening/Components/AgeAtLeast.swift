//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI


struct AgeAtLeast: ScreeningComponent {
    let title: LocalizedStringResource = "Date of Birth"
    let minAge: Int
    
    @Environment(\.calendar)
    private var cal
    
    @Environment(ScreeningDataCollection.self)
    private var data
    
    var body: some View {
        @Bindable var data = data
        DatePicker(
            selection: $data.dateOfBirth,
            in: Date.distantPast...Date.now,
            displayedComponents: .date
        ) {
            Text("When were you born?")
                .fontWeight(.medium)
        }
    }
    
    func evaluate(_ data: ScreeningDataCollection) -> Bool {
        let age = cal.dateComponents([.year], from: data.dateOfBirth, to: .tomorrow).year ?? 0
        return age >= minAge
    }
}
