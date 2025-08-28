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
            
            // Daftar Toko
            List(viewModel.filteredStores) { store in
                StoreRowView(store: store)
                    .onTapGesture {
                        viewModel.selectedStore = store
                    }
            }
            .listStyle(.plain)
        }
    }
}
