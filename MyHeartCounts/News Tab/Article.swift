//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import Foundation
import MarkdownUI
import SpeziFoundation
import SpeziStudyDefinition
import SpeziViews
import SwiftUI


struct Article: Codable, Hashable, Identifiable, Sendable {
    enum ImageReference: Hashable, Sendable {
        case url(URL)
        case asset(String)
    }
    
    
    struct Tag: Codable, Hashable, Sendable {
        let title: String
        let color: Color
        
        init(title: String, color: Color) {
            self.title = String(title.trimmingLeadingAndTrailingWhitespace())
            self.color = color
        }
    }
    let id: UUID
    let title: String
    let date: Date?
    let tags: [Tag]
    let lede: String?
    let headerImage: ImageReference?
    let body: String
    
    init(
        id: UUID,
        title: String,
        date: Date? = nil,
        tags: [Tag] = [],
        lede: String? = nil,
        headerImage: ImageReference? = nil, // swiftlint:disable:this function_default_parameter_at_end
        body: String
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.tags = tags.filter { !$0.title.isEmpty }
        self.lede = lede
        self.headerImage = headerImage
        self.body = body
    }
}


extension Article.Tag {
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


extension Article.ImageReference: RawRepresentable, Codable {
    typealias RawValue = String
    
    var rawValue: String {
        switch self {
        case .url(let url):
            url.absoluteURL.absoluteString
        case .asset(let name):
            name
        }
    }
    
    init?(rawValue: String) {
        if rawValue.starts(with: "https://"), let url = try? URL(rawValue, strategy: .url) {
            self = .url(url)
        } else {
            self = .asset(rawValue)
        }
    }
    
    init(from decoder: any Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(RawValue.self)
        if let _self = Self(rawValue: rawValue) {
            self = _self
        } else {
            throw NSError(domain: "edu.stanford.MHC", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Unable to decode '\(Self.self)' from rawValue '\(rawValue)'"
            ])
        }
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}


extension Article {
    init(_ other: StudyDefinition.InformationalComponent) {
        self.init(
            id: other.id,
            title: other.title,
            headerImage: .asset(other.headerImage), // we'll need to switch this over to a (file?) URL once we have study bundles!
            body: other.body
        )
    }
}


// MARK: Utility Views

struct TagView: View {
    private static let cornerRadius: CGFloat = 7
    let tag: Article.Tag
    
    var body: some View {
        Text(tag.title)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white) // TODO make this dependent on how dark/bright the tag color is?
            .padding(EdgeInsets(horizontal: 7, vertical: 3))
            .background(tag.color, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
    }
}


extension Article {
    @ViewBuilder var imageView: some View {
        switch headerImage {
        case nil:
            Color.clear
        case .asset(let name):
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaledToFill()
        case .url(let url):
            AsyncImage(url: url)
        }
    }
}
