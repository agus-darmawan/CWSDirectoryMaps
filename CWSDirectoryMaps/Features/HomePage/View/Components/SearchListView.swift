//
//  SearchListView.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 28/08/25.
//

import SwiftUI

struct SearchListView: View {
    @ObservedObject var viewModel: DirectoryViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            CategoryFilterView(
                categories: StoreCategory.allCases,
                selectedCategory: $viewModel.selectedCategory,
                onSelect: viewModel.selectCategory
            )
            .padding(.vertical)
            .accessibilityLabel("Category filters")
            .accessibilityHint("Select a category to filter search results")
            
            List(viewModel.filteredStores) { store in
                StoreRowView(store: store)
                    .onTapGesture {
                        viewModel.selectStore(store)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(store.name), \(store.category.rawValue)")
                    .accessibilityHint("Tap to view details for \(store.name)")
                    .accessibilityAddTraits(.isButton)
            }
            .listStyle(.plain)
            .accessibilityLabel("Search results list")
            .accessibilityValue("\(viewModel.filteredStores.count) results found")
        }
    }
}
