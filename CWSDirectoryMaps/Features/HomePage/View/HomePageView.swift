//
//  HomePageView.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 28/08/25.
//

import SwiftUI

struct HomePageView: View {
    
    @EnvironmentObject var dataManager: DataManager
    
    @StateObject private var viewModel = DirectoryViewModel()
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    VStack {
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
                        .accessibilityLabel("Search for stores and facilities")
                        .accessibilityHint("Tap to search for stores, restaurants, or facilities in the mall")
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                    }
                    .background(Color(.systemBackground))
                    .zIndex(1000)
                    .allowsHitTesting(true)
                    
                    if viewModel.isSearching {
                        if viewModel.isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .accessibilityLabel("Loading search results")
                                Text("Loading...")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground))
                        } else if let errorMessage = viewModel.errorMessage {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.title)
                                    .foregroundColor(.orange)
                                    .accessibilityHidden(true)
                                
                                Text("Error Loading Data")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .accessibilityLabel("Error loading search data")
                                
                                Text(errorMessage)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .accessibilityLabel("Error details: \(errorMessage)")
                                
                                Button("Retry") {
                                    viewModel.refreshData()
                                }
                                .buttonStyle(.borderedProminent)
                                .accessibilityLabel("Retry loading data")
                                .accessibilityHint("Tap to try loading the data again")
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground))
                        } else {
                            SearchListView(viewModel: viewModel)
                                .background(Color(.systemBackground))
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .accessibilityLabel("Search results")
                                .accessibilityHint("List of stores and facilities matching your search")
                                .zIndex(999)
                        }
                    } else {
                        ZStack {
                            MapView()
                                .accessibilityLabel("Interactive mall map")
                                .accessibilityHint("Shows the mall layout with different floors. Use the floor selector to switch between levels.")
                                .allowsHitTesting(!viewModel.isSearching)
                                .clipped()
                        }
                        .zIndex(1)
                    }
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
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
            .onAppear {
                viewModel.setup(dataManager: dataManager)
            }
            .overlay(
                Group {
                    if viewModel.isLoading && viewModel.allStores.isEmpty {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .overlay(
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .accessibilityLabel("Loading mall directory")
                                    
                                    Text("Loading...")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .accessibilityHidden(true)
                                }
                                    .padding(24)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(12)
                            )
                            .zIndex(2000)
                    }
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

#Preview {
    HomePageView()
        .environmentObject(DataManager())
}
