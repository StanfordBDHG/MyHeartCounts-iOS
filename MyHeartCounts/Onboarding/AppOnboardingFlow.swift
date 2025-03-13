//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Spezi
@_spi(TestingSupport)
import SpeziAccount
import SpeziFirebaseAccount
import SpeziHealthKit
import SpeziNotifications
import SpeziOnboarding
import SpeziStudy
import SwiftUI


//@Observable
//final class Counter {
//    var value: UInt64 = 0
//}
//
//
//struct TestPage: View {
//    @Environment(Counter.self)
//    private var counter
//    
//    var body: some View {
//        Form {
//            
//        }
//    }
//}



@Observable
final class ObservableBox<Value> {
    var value: Value
    
    init(_ value: Value) {
        print("-[\(Self.self) \(#function)]")
        self.value = value
    }
}

/// Displays a multi-step onboarding flow for the My Heart Counts iOS app
///
/// - Note: This is the general app onboarding flow, **not** the study-specific onboarding
struct AppOnboardingFlow: View {
//    @Environment(StudyManager.self)
//    private var mhc
//    @Environment(HealthKit.self)
//    private var healthKitDataSource
    
    @Environment(\.scenePhase)
    private var scenePhase
    @Environment(\.notificationSettings)
    private var notificationSettings
    
    @AppStorage(StorageKeys.onboardingFlowComplete)
    private var completedOnboardingFlow = false
    
    @State private var localNotificationAuthorization = false
    @State private var data = ScreeningDataCollection()
    
    
//    func makePage(@ViewBuilder _ content: () -> some View) -> some View {
//        Form {
//            NavigationLink {
//                LazyView {
//                    makePage {
//                        Text("Next")
//                    }
//                }
//            } label: {
//                content()
//            }
//        }
//    }
    
    @Binding private var path: [String]
    
//    @State private var path = ObservableBox<[String]>([])
    
    
    init(path: Binding<[String]>) {
        print("-[\(Self.self) \(#function)]")
        _path = path
    }
    
    var body: some View {
        let _ = Self._printChanges()
        let _ = print("path: \(path)")
//        @Bindable var path = path
//        NavigationStack(path: $path) {
//            Welcome()
//                .navigationDestination(for: String.self) { value in
//                    if value == "\(TMPTestView.self)" {
//                        TMPTestView()
//                    } else {
//                        ContentUnavailableView("Uh Oh", systemSymbol: .partyPopper)
//                    }
//                }
//        }
//        .onChange(of: path, initial: true) { oldValue, newValue in
//            print("PATH CHANGED: \(oldValue) --> \(newValue)")
//        }
        OnboardingStack(onboardingFlowComplete: $completedOnboardingFlow) {
            // TOOD include smth like this?
//            BetaDisclaimer()
            Welcome()
//            TMPTestView()
            
            SinglePageScreening(title: "Screening", subtitle: "Before we can continue,\nwe need to learn a little about you") {
                AgeAtLeast(minAge: 18)
                IsFromRegion(allowedRegion: .unitedStates)
                SpeaksLanguage(allowedLanguage: .init(identifier: "en_US"))
                CanPerformPhysicalActivity()
            }
            
            if !FeatureFlags.disableFirebase {
                AccountOnboarding()
            }
            #if !(targetEnvironment(simulator) && (arch(i386) || arch(x86_64)))
            Consent()
            #endif
            
            if HKHealthStore.isHealthDataAvailable() {
                // IDEA instead of having this in an if, we should probably have a full-screen "you can't participate" thing if the user doesn't have HealthKit?
                HealthKitPermissions()
            }
            
            if !localNotificationAuthorization {
                NotificationPermissions()
            }
            
//            TMPTestView()
            
//            FinalEnrollmentStep()
        }
        .id("OnboardingViewStack")
        .environment(data)
        .interactiveDismissDisabled(!completedOnboardingFlow)
        .onChange(of: scenePhase, initial: true) {
            guard case .active = scenePhase else {
                return
            }
            Task {
                localNotificationAuthorization = await notificationSettings().authorizationStatus == .authorized
            }
        }
    }
}



@Observable
@MainActor
final class SpeziAccessorModule: Module, EnvironmentAccessible, Sendable {
    @ObservationIgnored @Application(\.spezi) var spezi
}


struct TMPTestView: View {
    @Environment(OnboardingNavigationPath.self)
    private var onboardingNavigationPath
    @Environment(SpeziAccessorModule.self)
    private var speziAccessor
    
    @Environment(TestModule.self)
    private var testModule: TestModule?
    
    var body: some View {
        Form {
            Section {
                Text("\(unsafeBitCast(onboardingNavigationPath, to: uintptr_t.self))")
            }
            Section {
                Button("Inject Module") {
                    speziAccessor.spezi.loadModule(TestModule())
                }
            }
            Section {
                LabeledContent("Is TestModule injected?", value: "\(testModule != nil)")
            }
        }
    }
}
