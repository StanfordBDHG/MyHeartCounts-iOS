//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SFSafeSymbols
import SwiftUI


struct DemographicsButton: View {
    @State private var isPresentingDemographicsSheet = false
    
    let allowDragToDismiss: Bool
    
    var body: some View {
        Button {
            isPresentingDemographicsSheet = true
        } label: {
            Label("Demographics", systemSymbol: .personTextRectangle)
        }
        .sheet(isPresented: $isPresentingDemographicsSheet) {
            NavigationStack {
                DemographicsForm()
                    .interactiveDismissDisabled(!allowDragToDismiss)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            if #available(iOS 26, *) {
                                Button(role: .confirm) {
                                    isPresentingDemographicsSheet = false
                                }
                            } else {
                                Button("Done") {
                                    isPresentingDemographicsSheet = false
                                }
                                .bold()
                            }
                        }
                    }
            }
        }
    }
}
