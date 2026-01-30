//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


/// Intended to be used as the content of a Form/List Section; displays information about how a Score is computed, and what the percise values mean.
struct ScoreExplanationSection: View {
    let scoreResult: ScoreResult
    
    var body: some View {
        switch scoreResult.definition.variant {
        case let .distinctMapping(_, bands, explainer):
            makeSection(for: explainer, matchingBandIdx: { () -> Int? in
                guard bands.count == explainer.bands.count, let inputValue = scoreResult.inputValue else {
                    return nil
                }
                return bands.firstIndex { $0.matches(inputValue) }
            }())
        case .range(_, let explainer):
            makeSection(for: explainer)
        case .custom(_, let explainer):
            makeSection(for: explainer)
        }
    }
    
    private func makeSection(for explainer: ScoreDefinition.TextualExplainer, matchingBandIdx: Int? = nil) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(explainer.bands.indices), id: \.self) { idx in
                    let band = explainer.bands[idx]
                    makeColorBar(didMatch: idx == matchingBandIdx, background: band.background) {
                        HStack {
                            if let leadingText = band.leadingText {
                                Text(leadingText)
                            }
                            Spacer()
                            if let trailingText = band.trailingText {
                                Text(trailingText)
                            }
                        }
                        .frame(maxHeight: .infinity) // required to make the bar sufficiently tall if there is only a single row. don't ask me why.
                        .padding(.vertical, 2)
                        .padding(.top, idx == 0 ? 4 : 0)
                        .padding(.bottom, idx == explainer.bands.count - 1 ? 4 : 0)
                    }
                }
            }
        } header: {
            Text("Score Result")
                .padding(.leading, 16)
                .padding(.vertical, 8)
        } footer: {
            if let footerText = explainer.footerText {
                Text(footerText)
                    .padding()
            }
        }
        .listRowInsets(.zero)
    }
    
    private func makeColorBar(
        didMatch: Bool,
        background: ScoreDefinition.TextualExplainer.Band.Background,
        @ViewBuilder content: () -> some View
    ) -> some View {
        HStack {
            content()
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
        .transforming { view in
            switch background {
            case .color(let color):
                view.background(color)
            case .gradient(let gradient):
                view.background(
                    LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing)
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .foregroundStyle(.black)
        .font(.subheadline.weight(didMatch ? .semibold : .medium))
    }
}
