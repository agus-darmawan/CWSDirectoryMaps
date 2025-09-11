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
    @StateObject var pathfindingManager = PathfindingManager()
    @State var pathWithLabels: [(point: CGPoint, label: String)] = []
    @State private var currentFloor: Floor = Floor.ground

    
    var body: some View {
        NavigationView {
            GeometryReader { _ in
                VStack(spacing: 0) {
                    searchBarSection
                    
                    if viewModel.isSearching {
                        searchResultsSection
                    } else {
                        mapSection
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
                        isPresented: Binding(
                            get: { viewModel.selectedStore != nil },
                            set: { _ in viewModel.selectedStore = nil }
                        )
                    )
                }
            }
            .onAppear {
                viewModel.setup(dataManager: dataManager)
            }
            .overlay(loadingOverlay)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Subviews

private extension HomePageView {
    
    var searchBarSection: some View {
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
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .zIndex(1000)
        .allowsHitTesting(true)
    }
    
    @ViewBuilder
    var searchResultsSection: some View {
        if viewModel.isLoading {
            loadingSearchSection
        } else if let errorMessage = viewModel.errorMessage {
            errorSearchSection(errorMessage)
        } else {
            SearchListView(viewModel: viewModel)
                .background(Color(.systemBackground))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .accessibilityLabel("Search results")
                .accessibilityHint("List of stores and facilities matching your search")
                .zIndex(999)
        }
    }
    
    var mapSection: some View {
        ZStack {
            IntegratedMapView(
                dataManager: dataManager,
                pathWithLabels: $pathWithLabels,
                pathfindingManager: pathfindingManager,
                currentFloor: $currentFloor
            )
            .accessibilityLabel("Interactive mall map")
            .accessibilityHint("Shows the mall layout with different floors. Use the floor selector to switch between levels.")
            .allowsHitTesting(!viewModel.isSearching)
            .clipped()
        }
        .zIndex(1)
    }
    
    var loadingSearchSection: some View {
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
    }
    
    func errorSearchSection(_ errorMessage: String) -> some View {
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
    }
    
    @ViewBuilder
    var loadingOverlay: some View {
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
}

// MARK: - Preview

#Preview {
    HomePageView()
        .environmentObject(DataManager())
}
