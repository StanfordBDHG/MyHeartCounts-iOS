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
    
    @State private var isInitialLoad = false
    @State private var presentedArticle: Article?
    
    var body: some View {
        NavigationStack { // swiftlint:disable:this closure_body_length
            Group {
                if isInitialLoad {
                    ProgressView("Fetching…")
                } else if newsManager.articles.isEmpty {
                    if let error = newsManager.loadingError {
                        ContentUnavailableView(
                            "No Internet",
                            systemSymbol: .networkSlash,
                            description: Text(String(describing: error))
                        )
                    } else {
                        ContentUnavailableView(
                            "No News Yet",
                            systemSymbol: .newspaper,
                            description: Text("Feel free to check back later!")
                        )
                    }
                } else {
                    makeContent(for: newsManager.articles)
                }
            }
            .navigationTitle("News")
            .toolbar {
                accountToolbarItem
            }
            .task {
                if newsManager.articles.isEmpty {
                    isInitialLoad = true
                    await newsManager.refresh()
                    isInitialLoad = false
                } else {
                    await newsManager.refresh()
                }
            }
            .refreshable {
                await newsManager.refresh()
            }
            .sheet(item: $presentedArticle) { article in
                ArticleSheet(article: article)
            }
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
