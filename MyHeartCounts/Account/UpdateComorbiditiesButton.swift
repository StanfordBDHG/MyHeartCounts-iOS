//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziAccount
import SwiftUI


struct UpdateComorbiditiesButton: View {
    @Environment(Account.self)
    private var account
    
    @State private var showSheet = false
    @State private var demographicsData = DemographicsData()
    
    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack {
                Text("UPDATE_COMORBIDITIES_BUTTON_TITLE")
                    .foregroundStyle(.textLabel)
                Spacer()
                DisclosureIndicator()
            }
        }
        .disabled(account.details == nil)
        .task {
            demographicsData.populateIfEmpty(from: account)
        }
        .sheet(isPresented: $showSheet) {
            @Bindable var data = demographicsData
            NavigationStack {
                ComorbiditiesPicker(selection: $data[\.comorbidities].withDefault(Comorbidities()))
                    .navigationBarTitleDisplayMode(.inline)
                    .interactiveDismissDisabled()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            closeSheetButton
                        }
                    }
            }
        }
    }
    
    @ViewBuilder private var closeSheetButton: some View {
        // look into using an AsyncButton here
        if #available(iOS 26, *) {
            Button(role: .confirm) {
                closeSheet()
            }
        } else {
            Button("Done") {
                closeSheet()
            }
        }
    }
    
    private func closeSheet() {
        showSheet = false
        Task {
            try? await demographicsData.flush()
        }
    }
}
