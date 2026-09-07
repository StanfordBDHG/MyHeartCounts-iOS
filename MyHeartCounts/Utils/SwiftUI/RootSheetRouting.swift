//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import SwiftUI


/// OS-version-specific behavior toggles.
enum OSQuirks {
    /// iOS 26.5 re-hosts the content of first-level sheets presented from within `TabView > NavigationStack`
    /// in response to UIKit presentation events (alert/confirmationDialog teardown; menu-picker presentation
    /// within a child sheet), resetting all descendant `@State` and dismissing any child presentations
    /// anchored in that content.
    ///
    /// Not present on iOS 26.4 or 27.0. See also FB23536382 and FB23551259.
    static let firstLevelSheetRehosting: Bool = {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return version.majorVersion == 26 && version.minorVersion == 5
    }()
}


extension EnvironmentValues {
    /// Whether the view is part of a presentation chain rooted at the ``SwiftUICore/View/rootSheetAnchor()``,
    /// i.e. a chain that is immune to ``OSQuirks/firstLevelSheetRehosting``.
    @Entry var isInRootAnchoredChain = false
}


/// Presents sheets on behalf of views whose own `.sheet` would constitute a re-host-vulnerable
/// first-level presentation (see ``OSQuirks/firstLevelSheetRehosting``).
///
/// Mirrors the `taskPerformingAnchor()` pattern: the router travels down the environment;
/// the anchor (installed at the root, outside the `TabView`) owns the actual presentation.
@MainActor
@Observable
final class RootSheetRouter {
    struct Entry: Identifiable {
        let id: UUID
        let content: @MainActor () -> AnyView
        /// Called when the sheet gets dismissed by the user/system (rather than via ``RootSheetRouter/dismiss(id:)``),
        /// so that the requesting view can reset its own presentation state.
        let onUserDismiss: @MainActor () -> Void
    }

    fileprivate(set) var current: Entry?

    func present(
        id: UUID,
        onUserDismiss: @escaping @MainActor () -> Void,
        content: @escaping @MainActor () -> AnyView
    ) {
        current = Entry(id: id, content: content, onUserDismiss: onUserDismiss)
    }

    func dismiss(id: UUID) {
        if current?.id == id {
            current = nil
        }
    }
}


extension View {
    /// Installs the root sheet anchor used by ``SwiftUICore/View/adaptiveSheet(isPresented:content:)``.
    ///
    /// Apply once, at the root of the view hierarchy, **outside the `TabView`**
    /// (i.e., next to `taskPerformingAnchor()`).
    func rootSheetAnchor() -> some View {
        modifier(RootSheetAnchor())
    }

    /// Drop-in replacement for `.sheet(isPresented:content:)`.
    ///
    /// On OS versions unaffected by ``OSQuirks/firstLevelSheetRehosting``, and whenever this view
    /// already lives inside a presentation, this is exactly `.sheet`. On affected OS versions,
    /// presentations that would otherwise be re-host-vulnerable first-level sheets are routed to the
    /// ``SwiftUICore/View/rootSheetAnchor()`` instead. State and content ownership stay with the caller either way.
    func adaptiveSheet(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping @MainActor () -> some View
    ) -> some View {
        modifier(AdaptiveSheet(isPresented: isPresented, sheetContent: content))
    }

    // periphery:ignore - API
    /// Drop-in replacement for `.sheet(item:content:)`.
    func adaptiveSheet<Item: Identifiable>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping @MainActor (Item) -> some View
    ) -> some View {
        modifier(AdaptiveItemSheet(item: item, sheetContent: content))
    }
}


private struct RootSheetAnchor: ViewModifier {
    @State private var router = RootSheetRouter()

    private var entryBinding: Binding<RootSheetRouter.Entry?> {
        Binding {
            router.current
        } set: { newValue in
            if newValue == nil, let old = router.current {
                router.current = nil
                old.onUserDismiss()
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .environment(router)
            .sheet(item: entryBinding) { entry in
                entry.content()
                    .environment(\.isInRootAnchoredChain, true)
            }
    }
}


private struct AdaptiveSheet<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let sheetContent: @MainActor () -> SheetContent

    @Environment(RootSheetRouter.self)
    private var router: RootSheetRouter?
    @Environment(\.isInRootAnchoredChain)
    private var isInRootAnchoredChain
    @Environment(\.isPresented)
    private var isViewPresented

    @State private var token = UUID()

    /// Whether the presentation gets routed to the root anchor instead of being performed locally.
    ///
    /// NOTE: every input here is constant for the lifetime of this view's identity
    /// (the quirk flag is process-constant; the environment values are position-constants),
    /// so the branch in `body` never flips at runtime.
    private var reroutes: Bool {
        OSQuirks.firstLevelSheetRehosting
            && router != nil
            && !isInRootAnchoredChain
            && !isViewPresented
    }

    func body(content: Content) -> some View {
        if reroutes {
            content
                .onChange(of: isPresented, initial: true) { _, newValue in
                    if newValue {
                        router?.present(id: token, onUserDismiss: { isPresented = false }) {
                            AnyView(sheetContent())
                        }
                    } else {
                        router?.dismiss(id: token)
                    }
                }
                // mirror local-sheet semantics: if the requesting view leaves the hierarchy
                // (e.g., sidebar-adaptable tab switch on iPad), take the sheet down with it.
                .onDisappear {
                    router?.dismiss(id: token)
                    isPresented = false
                }
        } else {
            content
                .sheet(isPresented: $isPresented, content: sheetContent)
        }
    }
}


private struct AdaptiveItemSheet<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Binding var item: Item?
    let sheetContent: @MainActor (Item) -> SheetContent

    @Environment(RootSheetRouter.self)
    private var router: RootSheetRouter?
    @Environment(\.isInRootAnchoredChain)
    private var isInRootAnchoredChain
    @Environment(\.isPresented)
    private var isViewPresented

    @State private var token = UUID()

    /// See ``AdaptiveSheet/reroutes``.
    private var reroutes: Bool {
        OSQuirks.firstLevelSheetRehosting
            && router != nil
            && !isInRootAnchoredChain
            && !isViewPresented
    }

    func body(content: Content) -> some View {
        if reroutes {
            content
                .onChange(of: item?.id, initial: true) { _, _ in
                    if let item {
                        router?.present(id: token, onUserDismiss: { self.item = nil }) {
                            AnyView(sheetContent(item))
                        }
                    } else {
                        router?.dismiss(id: token)
                    }
                }
                .onDisappear {
                    router?.dismiss(id: token)
                    item = nil
                }
        } else {
            content
                .sheet(item: $item, content: sheetContent)
        }
    }
}
