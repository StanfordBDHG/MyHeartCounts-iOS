//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import SpeziViews
import SwiftUI

/// Onboarding step intended to be used to signal to the user that the app was unable to fetch its study definition; most likely due to network connectivity issues.
struct UnableToLoadStudyDefinitionStep: View {
    @Environment(ManagedNavigationStack.Path.self)
    private var onboardingPath
    
    @Environment(StudyDefinitionLoader.self)
    private var studyLoader
    
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        switch studyLoader.studyDefinition {
        case nil:
            // the StudyLoader, for whatever reason, hasn't yet loaded the study.
            // it is extremely unlikely, if not even outright impossible, for us to end up in this View
            // with the loader being in this state, but just in case, we treat it as an unknown error and offer a retry functionality.
            makeBody(
                symbol: .xmarkOctagon,
                title: "Failed to Download Study Information",
                message: "The app was unable to load the study, but we're no sure why"
            ) {
                AsyncButton("Retry", state: $viewState) {
                    _ = try? await studyLoader.reload()
                }
            }
        case .failure(.unableToFetchFromServer(let error)):
            makeBody(symbol: .wifiSlash, title: "Network Issue", message: "Make sure your device is connected to the internet and try again") {
                Text("\(error)")
                AsyncButton("Retry", state: $viewState) {
                    _ = try? await studyLoader.reload()
                }
            }
        case .failure(.unableToDecode(let error)):
            makeBody(
                symbol: .xmarkOctagon,
                title: "Failed to Load Study into App",
                message: "The app was able to download the study, but failed to decode it.\nMake sure you have the newest version installed."
            ) {
                ShareLink(
                    item: "https://spezi.stanford.edu",
                    subject: Text("Subject?"),
                    message: Text("Message?")
                ) {
                    Text("Label?")
                }
            }
        case .success:
            // we were able to load the study, but somehow ended up in here regardless.
            // this should never happen, but if it does we simply go back to the previous step.
            Color.clear.onAppear {
                onboardingPath.removeLast()
            }
        }
        ContentUnavailableView(
            "Error Fetching Study Info",
            systemSymbol: .xmarkOctagon,
            description: Text("")
        )
    }
    
    
    @ViewBuilder
    private func makeBody(
        symbol: SFSymbol,
        title: LocalizedStringResource,
        message: LocalizedStringResource,
        @ViewBuilder actionButton: () -> some View
    ) -> some View {
        ContentUnavailableView {
            Image(systemSymbol: symbol)
            Text(title)
                .font(.headline)
        } description: {
            Text(message)
        } actions: {
            actionButton()
        }
    }
}
