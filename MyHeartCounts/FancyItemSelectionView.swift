//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


struct FancyItemSelectionView<Items: RandomAccessCollection, ID: Hashable, Tile: View>: View {
    typealias Item = Items.Element
    
    private let items: Items
    private let id: KeyPath<Item, ID>
    private let makeTile: @MainActor (Item) -> Tile
    @Binding private var selection: Item?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(items, id: id) { item in
                    Button {
                        selection = item
                    } label: {
                        makePickerButton(for: item)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
    
    init(
        _ items: Items,
        id: KeyPath<Item, ID>,
        selection: Binding<Item?>,
        @ViewBuilder makeTile: @MainActor @escaping (Item) -> Tile
    ) {
        self.items = items
        self.id = id
        self.makeTile = makeTile
        self._selection = selection
    }
    
    init(
        _ items: Items,
        selection: Binding<Item?>,
        makeTile: @MainActor @escaping (Item) -> Tile
    ) where Item: Identifiable, ID == Item.ID {
        self.init(items, id: \.id, selection: selection, makeTile: makeTile)
    }
    
    @ViewBuilder
    private func makePickerButton(for item: Item) -> some View {
        let isSelected = selection?[keyPath: id] == item[keyPath: id]
        makeTile(item)
            .padding()
            .frame(height: 51)
            .background() // maybe have smth fancy here?
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(isSelected ? .blue : .secondary, lineWidth: 3)
            }
    }
}
