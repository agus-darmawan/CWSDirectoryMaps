//
//  DirectoryView.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 28/08/25.
//

import SwiftUI

struct DirectoryView: View {
    @StateObject private var viewModel = DirectoryViewModel()
    
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                MapView()
                    .ignoresSafeArea()
                
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
                    
                    if viewModel.isSearching {
                        if viewModel.isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Loading...")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground))
                        } else if let errorMessage = viewModel.errorMessage {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.title)
                                    .foregroundColor(.orange)
                                
                                Text("Error Loading Data")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(errorMessage)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button("Retry") {
                                    viewModel.refreshData()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground))
                        } else {
                            SearchListView(viewModel: viewModel)
                                .background(Color(.systemBackground))
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    } else {
                        Spacer()
                    }
                }
                
                if viewModel.isLoading && viewModel.allStores.isEmpty {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                
                                Text("Loading...")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                                .padding(24)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(12)
                        )
                }
            }
            .navigationTitle("Directory")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: isSearchFieldFocused) { _, focused in
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isSearching = focused
                }
            }
            .refreshable {
                viewModel.refreshData()
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
    DirectoryView()
}
