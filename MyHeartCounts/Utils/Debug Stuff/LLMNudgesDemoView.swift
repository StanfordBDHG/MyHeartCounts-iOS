//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziAccount
import SpeziViews
import SwiftUI


struct LLMNudgesDemoView: View {
    @State private var nudges: [NudgeMessage] = []
    @State private var userData: UserDemographics?
    @State private var llmPrompt: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // swiftlint:disable attributes
    @Environment(OnDeviceNudgeService.self) private var nudgeService
    @Environment(Account.self) private var account
    // swiftlint:enable attributes
    
    var body: some View {
        List {
            if isLoading {
                ProgressView("Loading nudges...")
            } else if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundStyle(.red)
            } else {
                if let userData = userData {
                    Section("User Demographics") {
                        demographicsView(userData)
                    }
                }
                
                if let prompt = llmPrompt {
                    Section("LLM Prompt") {
                        Text(prompt)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                
                Section("Nudges (\(nudges.count))") {
                    ForEach(Array(nudges.enumerated()), id: \.offset) { _, nudge in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(nudge.title)
                                .font(.headline)
                            Text(nudge.body)
                                .font(.body)
                            Text(nudge.isLLMGenerated ? "LLM Generated" : "Predefined")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Nudges")
        .task {
            await loadData()
        }
    }
    
    @ViewBuilder
    private func demographicsView(_ data: UserDemographics) -> some View {
        if let gender = data.genderIdentity {
            Text("Gender: \(String(describing: gender))")
        }
        
        if let dob = data.dateOfBirth {
            let age = UserDataService.calculateAge(dateOfBirth: dob)
            Text("Age: \(age)")
        }
        
        if let stage = data.stageOfChange {
            Text("Stage of Change: \(stage.rawValue)")
        }
        
        if let education = data.educationLevel {
            Text("Education: \(education.rawValue)")
        }
        
        Text("Language: \(data.userLanguage)")
        
        if let group = data.participantGroup {
            Text("Participant Group: \(group)")
        }
        
        if let enrollment = data.dateOfEnrollment {
            let days = UserDataService.getDaysSinceEnrollment(dateOfEnrollment: enrollment)
            Text("Days Since Enrollment: \(days)")
        }
        
        if let timeZone = data.timeZone {
            Text("Time Zone: \(timeZone)")
        }
        
        if let comorbidities = data.comorbidities {
            let selectedList = getSelectedComorbidities(comorbidities)
            if selectedList.isEmpty {
                Text("Comorbidities: None")
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Comorbidities:")
                        .fontWeight(.semibold)
                    ForEach(selectedList, id: \.self) { name in
                        Text("• \(name)")
                            .font(.subheadline)
                    }
                }
            }
        }
    }
    
    private func getSelectedComorbidities(_ comorbidities: Comorbidities) -> [String] {
        var selectedNames: [String] = []
        
        let allComorbidities = Comorbidities.Comorbidity.primaryComorbidities +
                               Comorbidities.Comorbidity.secondaryComorbidities
        
        for comorbidity in allComorbidities {
            let status = comorbidities[comorbidity]
            if case .selected = status {
                selectedNames.append(String(localized: comorbidity.title))
            }
        }
        
        return selectedNames
    }
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            userData = try await UserDataService.getUserDemographics(account: account)
            
            if let userData = userData {
                llmPrompt = nudgeService.buildLLMPrompt(userData: userData)
            }
            
            nudges = try await nudgeService.createNudgeNotifications()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
