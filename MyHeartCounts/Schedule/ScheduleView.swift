////
//// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
////
//// SPDX-FileCopyrightText: 2023 Stanford University
////
//// SPDX-License-Identifier: MIT
////
//
//@_spi(TestingSupport) import SpeziAccount
//import SpeziScheduler
//import SpeziSchedulerUI
//import SpeziViews
//import SwiftUI
//
//
//struct ScheduleView: View {
//    
//    
//    
//    init(presentingAccount: Binding<Bool>) {
//        self._presentingAccount = presentingAccount
//    }
//}
//
//
//#if DEBUG
//#Preview {
//    @Previewable @State var presentingAccount = false
//
//    ScheduleView(presentingAccount: $presentingAccount)
//        .previewWith(standard: MyHeartCountsStandard()) {
//            MyHeartCountsScheduler()
//            AccountConfiguration(service: InMemoryAccountService())
//        }
//}
//#endif
