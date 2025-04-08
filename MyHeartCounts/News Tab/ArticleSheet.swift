//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziStudyDefinition
import SpeziViews
import SwiftUI


public struct ArticleSheet: View {
    public let content: Content
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                scrollViewContent
            }
            .navigationTitle("")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    DismissButton()
                }
            }
        }
    }
    
    
    @ViewBuilder private var scrollViewContent: some View {
        VStack(spacing: 0) {
            ZStack {
                Group {
                    if let headerImage = content.headerImage {
                        headerImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 271)
                VStack {
                    Spacer()
                    HStack {
                        Text(content.title)
                            .font(.title.bold())
                        Spacer()
                    }
                    .padding()
                    .background(Color.primary.colorInvert().opacity(0.75))
                }
                // IDEA what if we somehow give the text portion of the ZStack a gradual blur background?
            }
            Divider()
            Group {
                if let text = try? AttributedString(styledMarkdown: content.body) {
                    Text(text)
                } else {
                    ContentUnavailableView("Unable to process text", systemSymbol: .textPage)
                }
            }
            .padding([.horizontal, .top])
        }
    }
    
    public init(content: Content) {
        self.content = content
    }
}


extension ArticleSheet {
    public struct Content: Sendable {
        public let title: String
        public let date: Date?
        public let categories: [String]
        public let lede: String?
        public let headerImage: Image?
        public let body: String
        
        public init(
            title: String,
            date: Date? = nil,
            categories: [String] = [],
            lede: String? = nil,
            headerImage: Image? = nil, // swiftlint:disable:this function_default_parameter_at_end
            body: String
        ) {
            self.title = title
            self.date = date
            self.categories = categories.filter { !$0.isEmpty && !$0.allSatisfy(\.isWhitespace) }
            self.lede = lede
            self.headerImage = headerImage
            self.body = body
        }
    }
}

extension ArticleSheet.Content {
    init(_ other: StudyDefinition.InformationalComponent) {
        self.init(
            title: other.title,
            headerImage: Image(other.headerImage),
            body: other.body
        )
    }
}


extension AttributedString {
    // stolen from https://stackoverflow.com/a/74430546
    init(styledMarkdown markdownString: String) throws {
        var output = try AttributedString(
            markdown: markdownString,
            options: .init(
                allowsExtendedAttributes: true,
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            ),
            baseURL: nil
        )

        for (intentBlock, intentRange) in output.runs[AttributeScopes.FoundationAttributes.PresentationIntentAttribute.self].reversed() {
            guard let intentBlock = intentBlock else { continue }
            for intent in intentBlock.components {
                switch intent.kind {
                case .header(level: let level):
                    switch level {
                    case 1:
                        output[intentRange].font = .system(.title).bold()
                    case 2:
                        output[intentRange].font = .system(.title2).bold()
                    case 3:
                        output[intentRange].font = .system(.title3).bold()
                    default:
                        break
                    }
                default:
                    break
                }
            }
            
            if intentRange.lowerBound != output.startIndex {
                output.characters.insert(contentsOf: "\n\n", at: intentRange.lowerBound)
            }
        }

        self = output
    }
}
