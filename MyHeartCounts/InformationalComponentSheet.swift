//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI
import SpeziStudy
import SpeziViews



// TODO also use this for the NewsEntries!
struct ArticleSheet: View {
    struct Content: Sendable {
        let title: String
        let date: Date?
        let categories: [String]
        let lede: String?
        let headerImage: Image?
        let body: String
        
        init(
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
    
    let content: Content
    
    var body: some View {
        NavigationStack {
            ScrollView {
                scrollViewContent
            }
            .navigationTitle("") // TODO
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    DismissButton()
                }
            }
        }
    }
    
    
    @ViewBuilder
    private var scrollViewContent: some View {
        VStack(spacing: 0) {
            ZStack {
//                Image("Image3")
                //if let headerImage = content.headerImage {
                (content.headerImage ?? Image(""))
//                    headerImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 271)
                        .clipped()
//                }
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
                // TODO we need to somehow give the text portion of the ZStack a gradual blur background!
            }
            Divider()
//            Text(try! AttributedString(markdown: content.body))
            Group {
                if true {
//                    Text(try! AttributedString(
//                        markdown: "# ABCABC\n\nHello **There** uwuu",
////                        markdown: content.body,
//                        options: .init(allowsExtendedAttributes: false, interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible, languageCode: nil)
//                    ))
                    Text(try! AttributedString(styledMarkdown: content.body)) // swiftlint:disable:this force_try
//                        .font(.system(.body))
                        .font(.system(size: 19))
//                    Text(AttributedString(try! NSAttributedString(
//                        markdown: content.body,
//                        options: AttributedString.MarkdownParsingOptions.init(interpretedSyntax: .full),
//                        baseURL: nil
//                    )))
                } else {
                    Text(content.body)
                        .font(.body.monospaced())
                }
            }
                .padding([.horizontal, .top])
        }
    }
}


extension ArticleSheet.Content {
    init(_ other: NewsEntry) {
        self.init(
            title: other.title,
            date: other.date,
            categories: [other.category],
            lede: other.lede,
            headerImage: other.image.map { Image($0) },
            body: other.body
        )
    }
    
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
