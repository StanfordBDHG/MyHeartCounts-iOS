//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import SpeziStudy
import SpeziViews
import SwiftUI


struct NewsTab: RootViewTab {
    static var tabTitle: LocalizedStringResource { "News" }
    static var tabSymbol: SFSymbol { .newspaper }
    
    @State private var entries: PossiblyLoading<[NewsEntry]> = .loading
    @State private var presentedEntry: NewsEntry?
    
    var body: some View {
        NavigationStack {
            Group {
                switch entries {
                case .loading:
                    ProgressView("Fetching…")
                case .loaded(let entries):
                    makeContent(for: entries)
                case .error(let error):
                    ContentUnavailableView("No Internet", systemSymbol: .networkSlash, description: Text("\(error)"))
                }
            }
            .navigationTitle("News")
            .toolbar {
                accountToolbarItem
            }
            .task {
                await fetchContent()
            }
            .refreshable {
                await fetchContent()
            }
            .sheet(item: $presentedEntry) { entry in
                ArticleSheet(content: .init(entry))
            }
        }
    }
    
    private func fetchContent() async {
        do {
            #if true || targetEnvironment(simulator)
            try await Task.sleep(for: .seconds(0.5))
            entries = .loaded([
                .init(date: .yesterday, category: "Research", title: "Title1", image: "image1", lede: "Lede1", body: "Body1"),
                .init(date: .today, category: "Impact", title: "Title2", image: "image2", lede: "Lede2", body: "Body2")
            ])
            #else
            entries = .error(SimpleError("Not yet implemented"))
            #endif
        } catch {
            entries = .error(error)
        }
    }
    
    @ViewBuilder
    private func makeContent(for entries: [NewsEntry]) -> some View {
        Form {
            ForEach(entries) { entry in
                Section {
                    Button {
                        presentedEntry = entry
                    } label: {
                        makeCard(for: entry)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    
    @ViewBuilder
    private func makeCard(for entry: NewsEntry) -> some View {
        // make this look nice!
        // maybe have like transparency/vibrancy/etc?
        VStack(alignment: .leading) {
            HStack {
                Text(entry.category)
                    .foregroundStyle(.tertiary)
                Spacer()
                RelativeTimeLabel(date: entry.date)
                    .foregroundStyle(.secondary)
            }
            Text(entry.title)
                .font(.headline)
            Text(entry.lede)
                .font(.body)
        }
    }
}
