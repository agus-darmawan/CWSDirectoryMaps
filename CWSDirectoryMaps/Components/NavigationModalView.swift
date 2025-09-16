//
//  NavigationModalView.swift
//  CWSDirectoryMaps
//
//  Fixed version with proper search field management and state handling
//

import SwiftUI

struct NavigationModalView: View {
    @ObservedObject var viewModel: DirectoryViewModel
    @State private var navigationState: NavigationState
    @State private var startLocationText: String = ""
    @State private var destinationText: String = ""
    @State private var selectedCategory: StoreCategory? = nil
    @State private var showingSameLocationAlert: Bool = false
    @State private var activeField: ActiveField? = nil
    @State private var showDirectionView: Bool = false
    
    // FIXED: Separate search texts for independent field management
    @State private var startSearchText: String = ""
    @State private var destinationSearchText: String = ""
    
    // FIXED: Add focus state management
    @FocusState private var isStartFieldFocused: Bool
    @FocusState private var isDestinationFieldFocused: Bool
    
    var onDismiss: (() -> Void)? = nil

    private let selectedStore: Store
    @Environment(\.dismiss) var dismiss
    @State private var path: [(CGPoint, String)] = []
    
    enum ActiveField {
        case startLocation
        case destination
    }
    
    private var customBlueColor: Color {
        Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 64/255, green: 156/255, blue: 255/255, alpha: 1.0)
            } else {
                return UIColor(red: 0/255, green: 46/255, blue: 127/255, alpha: 1.0)
            }
        })
    }
    
    // FIXED: Computed property for filtered stores based on active field
    private var currentFilteredStores: [Store] {
        let searchQuery = activeField == .startLocation ? startSearchText : destinationSearchText
        return viewModel.filteredStoresForNavigation(query: searchQuery, category: selectedCategory)
    }
    
    init(viewModel: DirectoryViewModel, selectedStore: Store, mode: NavigationMode) {
        self.viewModel = viewModel
        self.selectedStore = selectedStore
        self.path = []
        
        var initialState = NavigationState(startLocation: nil, endLocation: nil, mode: mode)
        initialState.setLocation(selectedStore, for: mode)
        self._navigationState = State(initialValue: initialState)
        
        if mode == .fromHere {
            self._startLocationText = State(initialValue: selectedStore.name)
            self._activeField = State(initialValue: .destination)
        } else {
            self._destinationText = State(initialValue: selectedStore.name)
            self._activeField = State(initialValue: .startLocation)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                navigationContentView
            }
            .padding()
            
            Divider()
        }
        .alert("Same Location Selected", isPresented: $showingSameLocationAlert) {
            Button("OK") { }
        } message: {
            Text("Starting location and destination cannot be the same. Please select a different location.")
        }
        .fullScreenCover(isPresented: $showDirectionView) {
            if let start = navigationState.startLocation,
               let end = navigationState.endLocation {
                DirectionView(
                    destinationStore: end,
                    startLocation: start,
                    onDismiss: {
                        self.resetNavigationState()
                    },
                    viewModel: viewModel
                )
            }
        }
        // FIXED: Monitor focus changes to update active field
        .onChange(of: isStartFieldFocused) { _, focused in
            if focused {
                activeField = .startLocation
                // Update viewModel search text when field becomes active
                viewModel.searchText = startSearchText
            }
        }
        .onChange(of: isDestinationFieldFocused) { _, focused in
            if focused {
                activeField = .destination
                // Update viewModel search text when field becomes active
                viewModel.searchText = destinationSearchText
            }
        }
    }
    
    private func checkAndNavigateToDirection() {
        if navigationState.startLocation != nil && navigationState.endLocation != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showDirectionView = true
            }
        }
    }
    
    private var navigationContentView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                    }
                    .foregroundColor(.blue)
                }
                .padding(.bottom, 44)
                
                VStack(spacing: 0) {
                    // START LOCATION
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.blue)
                        
                        TextField("Search starting location", text: $startLocationText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .focused($isStartFieldFocused)
                            .onTapGesture {
                                activeField = .startLocation
                                isStartFieldFocused = true
                                isDestinationFieldFocused = false
                            }
                            .onChange(of: startLocationText) { _, newValue in
                                startSearchText = newValue
                                if activeField == .startLocation {
                                    viewModel.searchText = newValue
                                }
                                // Clear selected location if text doesn't match
                                if let currentStore = navigationState.startLocation {
                                    if newValue != currentStore.name {
                                        navigationState.startLocation = nil
                                    }
                                }
                            }
                        
                        Spacer()
                        
                        if navigationState.startLocation != nil {
                            Button(action: {
                                clearStartLocation()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    
                    // DESTINATION
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                        
                        TextField("Search destination", text: $destinationText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .focused($isDestinationFieldFocused)
                            .onTapGesture {
                                activeField = .destination
                                isDestinationFieldFocused = true
                                isStartFieldFocused = false
                            }
                            .onChange(of: destinationText) { _, newValue in
                                destinationSearchText = newValue
                                if activeField == .destination {
                                    viewModel.searchText = newValue
                                }
                                // Clear selected location if text doesn't match
                                if let currentStore = navigationState.endLocation {
                                    if newValue != currentStore.name {
                                        navigationState.endLocation = nil
                                    }
                                }
                            }
                        
                        Spacer()
                        
                        if navigationState.endLocation != nil {
                            Button(action: {
                                clearDestination()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    Divider()
                        .frame(height: 1)
                        .padding(.leading, 36)
                        .padding(.trailing, 56)
                )
                
                // SWAP BUTTON
                Button(action: {
                    swapLocations()
                }) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(width: 32, height: 32)
                .background(canReverse ? customBlueColor : Color(.systemGray3))
                .clipShape(Circle())
                .disabled(!canReverse)
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
            
            CategoryFilterView(
                categories: StoreCategory.allCases,
                selectedCategory: $selectedCategory,
                onSelect: { category in
                    if selectedCategory == category {
                        selectedCategory = nil
                    } else {
                        selectedCategory = category
                    }
                }
            )
            .padding(.vertical, 16)

            // FIXED: Use currentFilteredStores instead of viewModel.filteredStores
            List(currentFilteredStores) { store in
                StoreRowView(store: store)
                    .onTapGesture {
                        selectLocation(store)
                    }
            }
            .listStyle(.plain)
        }
        .onReceive(viewModel.$calculatedPath) { newPath in
            path = newPath
            print("Paths updated: \(path)")
        }
        .onChange(of: navigationState.startLocation) { _, _ in
            checkAndNavigateToDirection()
        }
        .onChange(of: navigationState.endLocation) { _, _ in
            checkAndNavigateToDirection()
        }
    }
    
    var canReverse: Bool {
        let hasStartLocation = navigationState.startLocation != nil
        let hasEndLocation = navigationState.endLocation != nil
        return hasStartLocation || hasEndLocation
    }
    
    // FIXED: Enhanced clear functions
    private func clearStartLocation() {
        navigationState.startLocation = nil
        startLocationText = ""
        startSearchText = ""
        if activeField == .startLocation {
            viewModel.searchText = ""
        }
        activeField = .startLocation
        isStartFieldFocused = true
        isDestinationFieldFocused = false
    }
    
    private func clearDestination() {
        navigationState.endLocation = nil
        destinationText = ""
        destinationSearchText = ""
        if activeField == .destination {
            viewModel.searchText = ""
        }
        activeField = .destination
        isDestinationFieldFocused = true
        isStartFieldFocused = false
    }
    
    // FIXED: Enhanced swap function
    private func swapLocations() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if navigationState.startLocation != nil && navigationState.endLocation == nil {
                navigationState.endLocation = navigationState.startLocation
                navigationState.startLocation = nil
                destinationText = startLocationText
                startLocationText = ""
                destinationSearchText = startSearchText
                startSearchText = ""
                activeField = .startLocation
                isStartFieldFocused = true
                isDestinationFieldFocused = false
                viewModel.searchText = ""
            } else if navigationState.endLocation != nil && navigationState.startLocation == nil {
                navigationState.startLocation = navigationState.endLocation
                navigationState.endLocation = nil
                startLocationText = destinationText
                destinationText = ""
                startSearchText = destinationSearchText
                destinationSearchText = ""
                activeField = .destination
                isDestinationFieldFocused = true
                isStartFieldFocused = false
                viewModel.searchText = ""
            } else if navigationState.startLocation != nil && navigationState.endLocation != nil {
                let tempLocation = navigationState.startLocation
                let tempText = startLocationText
                let tempSearchText = startSearchText
                
                navigationState.startLocation = navigationState.endLocation
                startLocationText = destinationText
                startSearchText = destinationSearchText
                
                navigationState.endLocation = tempLocation
                destinationText = tempText
                destinationSearchText = tempSearchText
                
                // Update viewModel search text based on active field
                if activeField == .startLocation {
                    viewModel.searchText = startSearchText
                } else {
                    viewModel.searchText = destinationSearchText
                }
            }
        }
    }
    
    private func selectLocation(_ store: Store) {
        switch activeField {
        case .startLocation:
            if navigationState.endLocation?.id == store.id {
                showingSameLocationAlert = true
                return
            }
            navigationState.startLocation = store
            startLocationText = store.name
            startSearchText = ""
            viewModel.searchText = ""
            // Move focus to destination field after selection
            activeField = .destination
            isStartFieldFocused = false
            isDestinationFieldFocused = true
            
        case .destination:
            if navigationState.startLocation?.id == store.id {
                showingSameLocationAlert = true
                return
            }
            navigationState.endLocation = store
            destinationText = store.name
            destinationSearchText = ""
            viewModel.searchText = ""
            // Move focus to start field after selection (or keep current focus)
            activeField = .startLocation
            isDestinationFieldFocused = false
            isStartFieldFocused = false // Don't auto-focus, let user choose
            
        case .none:
            if navigationState.startLocation == nil {
                navigationState.startLocation = store
                startLocationText = store.name
                startSearchText = ""
                activeField = .destination
                isStartFieldFocused = false
                isDestinationFieldFocused = true
            } else {
                if navigationState.startLocation?.id == store.id {
                    showingSameLocationAlert = true
                    return
                }
                navigationState.endLocation = store
                destinationText = store.name
                destinationSearchText = ""
                activeField = .startLocation
                isDestinationFieldFocused = false
                isStartFieldFocused = false
            }
            viewModel.searchText = ""
        }
    }
}

// FIXED: Enhanced extension for better initialization
extension NavigationModalView {
    init(viewModel: DirectoryViewModel, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self.selectedStore = Store(
            id: UUID().uuidString,
            name: "",
            category: .others,
            imageName: "",
            subcategory: "",
            description: "",
            location: "",
            website: nil,
            phone: nil,
            hours: "",
            detailImageName: "",
            graphLabel: nil
        )
        self.path = []
        self._navigationState = State(
            initialValue: NavigationState(startLocation: nil, endLocation: nil, mode: nil)
        )
        self._activeField = State(initialValue: .startLocation) // Default to start location field
    }
}

// FIXED: Enhanced reset function
extension NavigationModalView {
    func resetNavigationState() {
        navigationState.startLocation = nil
        navigationState.endLocation = nil
        startLocationText = ""
        destinationText = ""
        startSearchText = ""
        destinationSearchText = ""
        activeField = .startLocation // Reset to start location field
        isStartFieldFocused = false
        isDestinationFieldFocused = false
        viewModel.searchText = ""
        selectedCategory = nil
    }
}
