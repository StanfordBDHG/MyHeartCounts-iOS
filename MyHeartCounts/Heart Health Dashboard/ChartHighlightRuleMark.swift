//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Charts
import SwiftUI


struct ChartHighlightRuleMark<Value: Plottable, Content: View>: ChartContent {
    private let xValue: PlottableValue<Value>
    private let content: @MainActor () -> Content
    
    var body: some ChartContent {
        RuleMark(x: xValue)
            .foregroundStyle(Color.gray.opacity(0.3))
            .offset(yStart: -10)
            .zIndex(-1)
            .annotation(
                position: AnnotationPosition.top,
                alignment: Alignment.center,
                spacing: 0,
                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
            ) { (_: AnnotationContext) in
                content()
            }
    }
    
    init(x xValue: PlottableValue<Value>, @ViewBuilder content: @MainActor @escaping () -> Content) {
        self.xValue = xValue
        self.content = content
    }
    
    init(
        x xValue: PlottableValue<Value>,
        primaryText: @autoclosure @MainActor @escaping () -> String,
        secondaryText: @autoclosure @MainActor @escaping () -> String?
    ) where Content == ChartHighlightRuleMarkDefaultContentView {
        self.init(x: xValue) {
            ChartHighlightRuleMarkDefaultContentView(primaryText: primaryText(), secondaryText: secondaryText())
        }
    }
}


struct ChartHighlightRuleMarkDefaultContentView: View {
    let primaryText: String
    let secondaryText: String?
    
    var body: some View {
        VStack(alignment: .leading) {
            if let secondaryText {
                Text(secondaryText)
                    .font(.subheadline)
            }
            Text(primaryText)
                .font(.headline)
        }
        .padding(4)
        .background(Color.gray.opacity(0.5))
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
