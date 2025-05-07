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
    
    @Environment(NewsManager.self)
    private var newsManager
    
    @State private var articles: PossiblyLoading<[Article]> = .loading
    @State private var presentedArticle: Article?
    
    var body: some View {
        NavigationStack {
            Group {
                switch articles {
                case .loading:
                    ProgressView("Fetching…")
                case .loaded(let articles):
                    makeContent(for: articles)
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
            .sheet(item: $presentedArticle) { article in
                ArticleSheet(article: article)
            }
        }
    }
    
    private func fetchContent() async {
        do {
            articles = .loaded(try await newsManager.refresh())
        } catch {
            articles = .error(error)
        }
    }
    
    @ViewBuilder
    private func makeContent(for articles: [Article]) -> some View {
        Form {
            ForEach(articles) { article in
                Section {
                    Button {
                        presentedArticle = article
                    } label: {
                        ArticleCard(article: article)
                            .frame(height: 117)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(.zero)
                }
            }
        }
    }
}
