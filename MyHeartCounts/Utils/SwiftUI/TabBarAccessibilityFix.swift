//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import MyHeartCountsShared
import SwiftUI
import UIKit


/// A zero-size view that locates the enclosing window's `UITabBar` and directly applies
/// accessibility identifiers to its items and their backing views.
///
/// SwiftUI's own application of the identifiers (via `TabContent/accessibilityIdentifier(_:)`) places them
/// on the `UITabBarItem`s, but on iOS 26 the Liquid Glass tab bar's private button views (`_UITabButton`)
/// don't pick them up, so the buttons expose only their labels to accessibility clients such as XCUITest.
/// Re-applying the identifiers at the UIKit level is deterministic and idempotent.
///
/// The tab bar's item views materialize asynchronously after the view enters the window, so we retry
/// until the first successful application and then stop; identifiers survive tab switches, re-renders,
/// and backgrounding once set (verified empirically). `updateUIView` additionally re-applies them
/// whenever SwiftUI updates the surrounding TabView, as a free event-driven safety net.
private struct TabBarAccessibilityFixer: UIViewRepresentable {
    final class FixerView: UIView {
        var identifiers: [String] = []
        private var initialApplication: Task<Void, Never>?

        private static func findTabBars(in root: UIView) -> [UITabBar] {
            var tabBars: [UITabBar] = []
            func visit(_ view: UIView) {
                if let tabBar = view as? UITabBar {
                    tabBars.append(tabBar)
                }
                for subview in view.subviews {
                    visit(subview)
                }
            }
            visit(root)
            return tabBars
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            initialApplication?.cancel()
            initialApplication = nil
            guard window != nil else {
                return
            }
            initialApplication = Task { @MainActor [weak self] in
                for _ in 0..<40 { // the item views usually exist within a few hundred ms
                    guard let self, !Task.isCancelled else {
                        return
                    }
                    if self.apply() {
                        return
                    }
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }
        }

        /// Applies the identifiers; returns `true` once a fully-populated tab bar was handled.
        @discardableResult
        func apply() -> Bool {
            guard let window else {
                return false
            }
            // `UITabBarItem.view` is a private accessor (resolves to a `_UITabButton` on iOS 26);
            // the responds(to:) check makes us degrade to a no-op instead of throwing
            // NSUndefinedKeyException should a future UIKit remove it.
            let viewSelector = NSSelectorFromString("view")
            var success = false
            for tabBar in Self.findTabBars(in: window) {
                let items = tabBar.items ?? []
                var resolvedAllItemViews = !items.isEmpty
                for (item, identifier) in zip(items, identifiers) {
                    if item.accessibilityIdentifier != identifier {
                        item.accessibilityIdentifier = identifier
                    }
                    guard item.responds(to: viewSelector),
                          let itemView = item.perform(viewSelector)?.takeUnretainedValue() as? UIView else {
                        resolvedAllItemViews = false
                        continue
                    }
                    if itemView.accessibilityIdentifier != identifier {
                        itemView.accessibilityIdentifier = identifier
                    }
                }
                success = success || resolvedAllItemViews
            }
            return success
        }
    }

    let identifiers: [String]

    func makeUIView(context: Context) -> FixerView {
        let view = FixerView()
        view.identifiers = identifiers
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: FixerView, context: Context) {
        uiView.identifiers = identifiers
        // SwiftUI calls this on every update of the surrounding TabView (e.g. selection changes),
        // which makes for a free, event-driven re-application without any polling.
        uiView.apply()
    }
}


extension View {
    /// Works around an iOS 26 issue where accessibility identifiers applied to `Tab`s via
    /// `TabContent/accessibilityIdentifier(_:)` don't reliably make it onto the tab bar buttons'
    /// accessibility elements, which breaks XCUITest tab lookups (the buttons expose only their labels).
    ///
    /// Apply this to the `TabView` itself. `identifiers` are matched to the tab bar's items positionally.
    ///
    /// The workaround is only active while the app is being UI-tested (which includes the screenshotting
    /// flow; both go through `MHCTestCase`): accessibility identifiers are a purely programmatic surface —
    /// assistive technologies use labels — so outside of test automation nothing consumes them,
    /// and in production this is a complete no-op.
    @ViewBuilder
    func tabBarAccessibilityIdentifiersWorkaround(_ identifiers: [String]) -> some View {
        if ProcessInfo.isBeingUITested {
            background(TabBarAccessibilityFixer(identifiers: identifiers))
        } else {
            self
        }
    }
}
