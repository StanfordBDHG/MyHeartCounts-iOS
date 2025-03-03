//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all line_length


import Foundation
import class ModelsR4.Questionnaire
import Observation
import PDFKit
import SFSafeSymbols
import Spezi
import SpeziHealthKit
import SpeziScheduler
import SpeziStudy
import SwiftData
import SwiftUI


struct SimpleError: Error, LocalizedError {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
}


@Observable
@MainActor // TODO can we easily make this sendable w/out it also being MainActor-constrained?
final class MHC: Module, EnvironmentAccessible, Sendable {
    @ObservationIgnored @Dependency(HealthKit.self) private var healthKit
    @ObservationIgnored @Dependency(Scheduler.self) private var scheduler
    
    @ObservationIgnored @Application(\.logger) private var logger
    
    @ObservationIgnored @NotNilAssignable var modelContext: ModelContext?
    
    private(set) var SPCs: [StudyParticipationContext] = []
    
    private(set) var actionCards: [ActionCard] = []
    
    
    func configure() {
        updateActionCards()
    }
}


// MARK: ActionCards

extension MHC {
    @MainActor
    struct ActionCard: Identifiable, Hashable {
        @MainActor
        enum Content: Hashable {
            case event(Event)
            case simple(SimpleContent)
            
            nonisolated func hash(into hasher: inout Hasher) {
                switch self {
                case .event(let event):
                    hasher.combine(event.id)
                case .simple(let content):
                    hasher.combine(content.id)
                }
            }
            
            nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
                switch (lhs, rhs) {
                case let (.event(lhs), .event(rhs)):
                    lhs.id == rhs.id
                case let (.simple(lhs), .simple(rhs)):
                    lhs == rhs
                case (.event, .simple), (.simple, .event):
                    false
                }
            }
        }
        
        @MainActor
        struct SimpleContent: Identifiable, Hashable {
            let id: String
            let symbol: SFSymbol?
            let title: String
            let message: String
        }
        
        let content: Content
        let action: Action
        
        nonisolated var id: AnyHashable {
            switch content {
            case .simple(let content):
                return content.id
            case .event(let event):
                return event.id
            }
        }
        
        @MainActor
        enum Action: Hashable, Codable {
            // TODO
            case listAllAvailableStudies
            case enrollInStudy(StudyDefinition)
            case presentInformationalStudyComponent(StudyDefinition.InformationalComponent)
            case answerQuestionnaire(Questionnaire, spcId: PersistentIdentifier)
        }
        
        
        fileprivate static let enrollInStudy = Self(content: .simple(.init(
            id: "enroll-in-study",
            symbol: .listTriangle,
            title: "Enroll in a Study",
            message: "Participate in one or multiple studies, to share data with scientific researchers, receive actionable advice on how you can improve and maintain your personal health, and help out others in the process." // swiftlint:disable:this line_length
    //                trailingAccessory: .disclosureIndicator
        )), action: .listAllAvailableStudies)
    }
}


extension MHC {
    private func updateActionCards() {
        actionCards = Array {
            ActionCard.enrollInStudy
            // TODO have more suff here? maybe somehow allow the server to show these non-schedule-managed in-app action cards?
        }
    }
}


// MARK: Study Participation and Lifrecycle Management

extension MHC {
    enum StudyEnrollmentError: Error, LocalizedError {
        /// The user tried to enroll into a study they are already enrolled in.
        case alreadyEnrolledInStudy
        /// The user tried to enroll into a study which defines a depdenency on some other study, which the user isn't enrolled in.
        case notEnrolledInDependency // TODO missingEnrollmentInStudyDependency?
        
        var errorDescription: String? {
            switch self {
            case .alreadyEnrolledInStudy:
                "You already are enrolled in this study"
            case .notEnrolledInDependency:
                "You cannot enroll in this study at this time, because the study has a dependency on another study, which you are not enrolled in"
            }
        }
    }
    
    
    func initialize(with modelContext: ModelContext) async throws {
        self.modelContext = modelContext
        SPCs = try modelContext.fetch(FetchDescriptor<StudyParticipationContext>())
        try registerStudyTasksWithScheduler(SPCs)
        try await setupStudyBackgroundComponents(SPCs)
        // TODO(@lukas) we need a thing (not here, probably in -configre or in the function that fetches the current study versions from the server) that deletes/stops all Tasks registered w/ the scheduler that don't correspond to valid study components anymore! eg: imagine we remove an informational component (or replace it w/ smth completely new). in that case we want to disable the schedule for that, instead of having it continue to run in the background!
    }
    
    
    private func registerStudyTasksWithScheduler(_ SPCs: some Collection<StudyParticipationContext>) throws {
        for SPC in SPCs {
            for (idx, schedule) in SPC.study.schedule.elements.enumerated() { // TODO using the index to identify these is a horrible idea!!! (but i also don't wanna give them individual ids?...)
                guard let component: StudyDefinition.Component = SPC.study.component(withId: schedule.componentId) else {
                    throw SimpleError("Unable to find component for id '\(schedule.componentId)'")
                }
                guard component.requiresUserInteraction else {
                    // if this is an internal component, we don't want to schedule it via SpeziScheduler.
                    continue
                }
                let category: Task.Category?
                let action: ActionCard.Action?
                switch component {
                case .questionnaire(id: _, let questionnaire):
                    //category = .custom("edu.stanford.spezi.MHC.task.questionnaire")
                    category = .questionnaire
                    action = .answerQuestionnaire(questionnaire, spcId: SPC.persistentModelID)
                case .informational(let component):
                    category = .informational
                    action = .presentInformationalStudyComponent(component)
                case .healthDataCollection:
                    fatalError()
                }
                let (task, _) = try scheduler.createOrUpdateTask(
                    id: "edu.stanford.spezi.MHC.studyComponentTask.\(SPC.study.id.uuidString).\(component.id)", // TOOD better schema here?!
                    title: component.displayTitle.map { "\($0)" } ?? "",
                    instructions: "",
                    category: category,
                    schedule: try .init(schedule, participationStartDate: SPC.enrollmentDate),
                    completionPolicy: schedule.completionPolicy,
                    scheduleNotifications: false, // TODO allow customizing this!! // TODO passing true here causes weird SwiftData crashes!!!
                    notificationThread: NotificationThread.none, // TODO!!!
                    tags: nil, // TODO?!
                    effectiveFrom: .now,
                    shadowedOutcomesHandling: .delete,
                    with: { context in
                        context.studyScheduledTaskAction = action
                    } // TODO use this for smth?
                )
                print("Scheduled task \(task)")
            }
        }
    }
    
    
    private func setupStudyBackgroundComponents(_ SPCs: some Collection<StudyParticipationContext>) async throws {
        for SPC in SPCs {
            for component in SPC.study.healthDataCollectionComponents {
                func setupSampleCollection(_ sampleTypes: some Collection<SampleType<some Any>>) async {
                    for sampleType in sampleTypes {
                        await healthKit.addHealthDataCollector(CollectSample(
                            sampleType,
                            start: .automatic,
                            continueInBackground: true,
                            predicate: nil
                        ))
                    }
                }
                await setupSampleCollection(component.sampleTypes.quantityTypes)
                await setupSampleCollection(component.sampleTypes.correlationTypes.flatMap(\.associatedQuantityTypes))
                await setupSampleCollection(component.sampleTypes.categoryTypes)
            }
        }
        // we want to request HealthKit auth once, at the end, for everything we just registered.
        try await healthKit.askForAuthorization()
    }
    
    
    // MARK: Study Enrollment
    func enroll(in study: StudyDefinition) async throws {
        // TODO big issue in this function is that, if we throw somewhere we kinda need to unroll _all_ the changes we've made so far
        // (which is much easier said that done...)
        guard let modelContext else {
            fatalError() // TODO
        }
        guard !SPCs.contains(where: { $0.study.id == study.id }) else {
            throw StudyEnrollmentError.alreadyEnrolledInStudy
        }
        
        if let dependency = study.metadata.studyDependency {
            guard SPCs.contains(where: { $0.study.id == dependency }) else {
                throw StudyEnrollmentError.notEnrolledInDependency
            }
        }
        
        let SPC = StudyParticipationContext(study: study)
        modelContext.insert(SPC)
        try modelContext.save()
        SPCs.append(SPC)
        print("ADDING TASKS FOR STUDY COMPONENTS")
        try registerStudyTasksWithScheduler(CollectionOfOne(SPC))
        try await setupStudyBackgroundComponents(CollectionOfOne(SPC))
    }
    
    
    func unenroll(from SPC: StudyParticipationContext) async throws {
        // TODO
        // - remove SPC from db
        // - inform server
        // - delete all tasks belonging to this SPC
        throw SimpleError("Not yet implemented!!!")
        // TODO questions:
        // - if we allow re-enrolling into a previously-enrolled study, we need the ability to schedule the tasks and then
        //   immediately check as completed everything up to today?
        //   or would that be irrelevant since the event list only looks at today+ already?
    }
}


// MARK: Consent Documents

extension MHC {
    enum ConsentDocumentContext {
        /// The user has consented to the app in general
        case generalAppUsage
        /// The user has consented to participation in the specified study.
        case studyEnrolment(StudyDefinition)
    }
    
    func importConsentDocument(_ pdf: PDFDocument, for context: ConsentDocumentContext) {
        // TODO do smth w/ the consent documents!
    }
}


extension Task.Context {
    // TODO for some reason only .json works? .propertyList (the default) fails to decode the input?!
    @Property(coding: .json) var studyScheduledTaskAction: MHC.ActionCard.Action?
}


extension Task.Category {
    static let informational = Self.custom("edu.stanford.spezi.MHC.task.informational")
}


extension View {
    func injectingCustomTaskCategoryAppearances() -> some View {
        self
            .taskCategoryAppearance(for: .informational, label: "Informational", image: .systemSymbol(.textRectanglePage))
    }
}



extension SpeziScheduler.Schedule {
    /// - parameter other: the study definition schedule element which should be turned into a `Schedule`
    /// - parameter participationStartDate: the date at which the user started to participate in the study.
    init(_ other: StudyDefinition.ScheduleElement, participationStartDate: Date) throws {
//        switch other.scheduleKind {
//        case .onceAtEnrollment:
//            throw SimpleError(".onceAtEnrollment not (yet?) supported")
//        case .atEndOfStudy:
//            throw SimpleError(".atEndOfStudy not (yet?) supported")
//        }
        switch other.scheduleKind {
        case .once(.studyBegin, let offset):
            self = .once(at: participationStartDate.advanced(by: offset.totalSeconds))
        case .once(.studyEnd, _):
            // TODO instead of throwing an error here, we probably wanna return nil,
            // since this is something where we do want to continue processing the remaining schedule elements!!!
            throw SimpleError(".once(.studyEnd) not supported!")
        case .once(.completion, offset: _):
            throw SimpleError(".once(.completionOf) not (yet?!) supported!")
        case let .repeated(.daily(interval, hour, minute), startOffsetInDays):
            self = .daily(
                interval: interval,
                hour: hour,
                minute: minute,
                second: 0,
                startingAt: participationStartDate.addingTimeInterval(60 * 60 * 24 * TimeInterval(startOffsetInDays)),
                end: .never,
                duration: .tillEndOfDay
            )
        case let .repeated(.weekly(interval, weekday, hour, minute), startOffsetInDays):
            self = .weekly(
                interval: interval,
                weekday: weekday,
                hour: hour,
                minute: minute,
                second: 0,
                startingAt: participationStartDate.addingTimeInterval(60 * 60 * 24 * TimeInterval(startOffsetInDays)),
                end: .never,
                duration: .tillEndOfDay
            )
        default:
            fatalError()
        }
//        case .repeated(., startOffset: <#T##Int#>)
//        case .repeated(<#T##Calendar.RecurrenceRule#>, startOffset: <#T##Int#>)
//        case .repeated(let recurrence, let startOffsetInDays):
//            //self = .init(startingAt: <#T##Date#>, duration: <#T##Duration#>, recurrence: <#T##Calendar.RecurrenceRule?#>)
//            self = .init(
//                startingAt: participationStartDate.addingTimeInterval(60 * 60 * 24 * TimeInterval(startOffsetInDays)),
//                recurrence: recurrence
//            )
//        }
    }
}
