//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


import Foundation
import SFSafeSymbols
import SpeziViews
import SwiftUI


struct NewsTabView: RootViewTab {
    static var tabTitle: LocalizedStringKey { "News" }
    static var tabSymbol: SFSymbol { .newspaper }
    
    @State private var entries: PossiblyLoading<[NewsEntry]> = .loading
    @State private var presentedEntry: NewsEntry?
    
    var body: some View {
        NavigationStack {
            Group {
                switch entries {
                case .loading:
                    ProgressView("Fetching…")
//                    ProgressView()
//                        .progressViewStyle(.circular)
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
            #if targetEnvironment(simulator)
            try await Task.sleep(for: .seconds(0.5))
            entries = .loaded([
                .init(date: .yesterday, category: "Research", title: "Title1", lede: "Lede1", body: "Body1"),
                .init(date: .today, category: "Impact", title: "Title2", lede: "Lede2", body: "Body2")
            ])
            #else
            entries = .error(SimpleError("Server not found")) // TODO implement this!
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
                        NewsEntryCard(entry: entry)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
//                    NavigationLink {
//                        // TODO reuse the InformationalStudyComponentSheet!
//                        Text("TODO")
//                    } label: {
//                        NewsEntryCard(entry: entry)
//                    }
                }
            }
        }
    }
}


private struct NewsEntryCard: View {
    let entry: NewsEntry
    
    var body: some View {
        // TODO make this look nice!
        // maybe have like transparency/vibrancy/etc?
        VStack(alignment: .leading) {
            HStack {
                Text(entry.category)
                    .foregroundStyle(.tertiary)
                Spacer()
                RelativeTimeLabel(date: entry.date)
                    .foregroundStyle(.secondary)
//                Text(entry.date, format: .dateTime) // TODO have this be formatted in a "smart" way, ie so that we use the time for <24h, then day (text) and time, and then after a threshold just the date?! (also make this generic! maybe have a RelativeTimeLabel in SpeziViews?!
            }
            Text(entry.title)
                .font(.headline)
            Text(entry.lede)
                .font(.body)
        }
    }
}




struct NewsEntry: Hashable, Codable, Sendable {
    let date: Date
    let category: String
    let title: String
    let lede: String
    let body: String
}

extension NewsEntry: Identifiable {
    struct ID: Hashable {
        private let date: Date
        private let title: String
        
        fileprivate init(_ entry: NewsEntry) {
            date = entry.date
            title = entry.title
        }
    }
    
    var id: ID {
        .init(self)
    }
}



// MARK: Utilities (TODO maybe move this somewhere else and turn it into a more general type/thing?)


enum PossiblyLoading<Value> {
    case loading
    case loaded(Value)
    case error(any Error)
}

extension PossiblyLoading: Sendable where Value: Sendable {}
