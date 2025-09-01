
//
//  HomePageView.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 28/08/25.
//

import SwiftUI

struct HomePageView: View {
    @StateObject private var viewModel = DirectoryViewModel()
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SearchBarView(
                      searchText: $viewModel.searchText,
                      isSearching: $viewModel.isSearching,
                      isSearchFieldFocused: $isSearchFieldFocused,
                      onClear: viewModel.clearSearch,
                      onCloseSearch: {
                          viewModel.exitSearch()
                          isSearchFieldFocused = false
                      }
                  )
                  .padding(.horizontal)
                  .padding(.top, 10)
                  .padding(.bottom, 8)
                .background(Color(.systemBackground))
                .zIndex(1)
                
                ZStack {
                    MapView()
                        .opacity(viewModel.isSearching ? 0 : 1)
                    if viewModel.isSearching {
                        SearchListView(viewModel: viewModel)
                            .background(Color(.systemBackground))
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
            .navigationTitle("Directory")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: isSearchFieldFocused) { _, focused in
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isSearching = focused
                }
            }
            .sheet(isPresented: .constant(viewModel.selectedStore != nil)) {
                if let store = viewModel.selectedStore {
   
                    TenantDetailModalView(
                        store: store,
                        viewModel: viewModel,
                        isPresented: Binding<Bool>(
                            get: { viewModel.selectedStore != nil },
                            set: { _ in viewModel.selectedStore = nil }
                        )
                    )
                }
            }
        }
    }
}

#Preview {
    HomePageView()
}

