//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import MarkdownUI
import SpeziStudyDefinition
import SpeziViews
import SwiftUI


struct ArticleSheet: View {
    let content: Content
    
    var body: some View {
        NavigationStack {
            ScrollView {
                scrollViewContent
            }
            // telling the scroll view to ignore the top safe area causes it to place its content underneath the navigation bar,
            // which we want since that in turn causes SwiftUI to make the navigation bar transparent when the scroll view is
            // scrolled all the way to the top, and to gradually make it opaque as you scroll down.
            .ignoresSafeArea(edges: .top)
//            .navigationTitle(content.title)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    DismissButton()
                }
                ToolbarItem(placement: .principal) {
                    navigationTitleView
                }
            }
        }
    }
    
    @ViewBuilder private var navigationTitleView: some View {
        VStack {
            Text(content.title)
                .font(.headline)
            // do we really want the date here?
            if let date = content.date {
                Text(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none))
                    .font(.subheadline)
            }
        }
    }
    
    @ViewBuilder private var scrollViewContent: some View {
        VStack(spacing: 0) {
            headlineImage
            Divider()
            Group {
                Markdown(.init(content.body))
            }
            .padding([.horizontal, .top])
        }
    }
    
    @ViewBuilder private var headlineImage: some View {
        // TODO ZStack vs .overlay here?
        ZStack { // swiftlint:disable:this closure_body_length
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
            .clipped()
            .background(.red)
            VStack {
                Spacer()
                VStack(alignment: .leading) {
                        Text(content.title)
                            .font(.title.bold())
                            .frame(alignment: .leading)
                    HStack {
                        if let date = content.date {
                            Text(DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none))
//                                .frame(alignment: .leading)
                                .layoutPriority(1)
                        }
                        Spacer()
                        let tags = HStack {
                            ForEach(content.tags.indices, id: \.self) { tagIdx in
                                TagView(tag: content.tags[tagIdx])
                            }
                        }
                        ViewThatFits {
                            tags
                            ScrollView(.horizontal, showsIndicators: false) {
                                tags
                            }
                            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.primary.colorInvert().opacity(0.75))
            }
            // IDEA what if we somehow give the text portion of the ZStack a gradual blur background?
        }
    }
    
    
    init(content: Content) {
        self.content = content
    }
}


extension ArticleSheet {
    struct Content: Sendable {
        struct Tag: Sendable, Codable, Hashable {
            let title: String
            let color: Color
            
            init(title: String, color: Color) {
                self.title = String(title.trimmingLeadingAndTrailingWhitespace())
                self.color = color
            }
        }
        let title: String
        let date: Date?
        let tags: [Tag]
        let lede: String?
        let headerImage: Image?
        let body: String
        
        init(
            title: String,
            date: Date? = nil,
            tags: [Tag] = [],
            lede: String? = nil,
            headerImage: Image? = nil, // swiftlint:disable:this function_default_parameter_at_end
            body: String
        ) {
            self.title = title
            self.date = date
            self.tags = tags.filter { !$0.title.isEmpty }
            self.lede = lede
            self.headerImage = headerImage
            self.body = body
        }
    }
}


extension ArticleSheet.Content.Tag {
    private enum CodingKeys: CodingKey {
        case title
        case color
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        color = Color(try container.decode(CodableColor.self, forKey: .color))
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(CodableColor(color), forKey: .color)
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


// MARK: Utility Views

private struct TagView: View {
    private static let cornerRadius: CGFloat = 7
    let tag: ArticleSheet.Content.Tag
    
    var body: some View {
        Text(tag.title)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white) // TODO make this dependent on how dark/bright the tag color is?
            .padding(EdgeInsets(horizontal: 7, vertical: 3))
            .background(tag.color, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
    }
}
