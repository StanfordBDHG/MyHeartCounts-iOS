//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziQuestionnaire
import SpeziScheduler
import SwiftUI


//struct EventView: View {
//    private let event: Event
//
//    @Environment(MyHeartCountsStandard.self) private var standard
//    @Environment(\.dismiss) private var dismiss
//
//    var body: some View {
//        if let questionnaire = event.task.questionnaire {
//            // TODO (this is a non-trivial change) maybe somehow add state restoration to SpeziQuestionnaire
//            // the idea here would be to have some mechamism by which we can somehow represent a partially-answered questionnaire,
//            // and then eg present the user w/ a button in the app to complete/continue a not-yet-fully-answered questionnaire,
//            // eg when the user closed the app or it crashed or smth
//            QuestionnaireView(questionnaire: questionnaire) { result in
//                dismiss()
//                switch result {
//                case .completed(let response):
//                    try? event.complete()
//                    await standard.add(response: response)
//                case .cancelled, .failed:
//                    break
//                }
//            }
//        } else {
//            NavigationStack {
//                ContentUnavailableView(
//                    "Unsupported Event",
//                    systemImage: "list.bullet.clipboard",
//                    description: Text("This type of event is currently unsupported. Please contact the developer of this app.")
//                )
//                    .toolbar {
//                        Button("Close") {
//                            dismiss()
//                        }
//                    }
//            }
//        }
//    }
//
//    init(_ event: Event) {
//        self.event = event
//    }
//}
