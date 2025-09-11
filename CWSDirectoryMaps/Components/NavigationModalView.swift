//
//  NavigationModalView.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 28/08/25.
//

import SwiftUI

struct NavigationModalView: View {
    @ObservedObject var viewModel: DirectoryViewModel
    @Binding var isPresented: Bool
    @State private var navigationState: NavigationState
    @State private var startLocationText: String = ""
    @State private var destinationText: String = ""
    @State private var selectedCategory: StoreCategory? = nil
    @State private var showingSameLocationAlert: Bool = false
    @State private var activeField: ActiveField? = nil
    @State private var showDirectionView: Bool = false
    
    private let selectedStore: Store
    
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
    
    init(viewModel: DirectoryViewModel, isPresented: Binding<Bool>, selectedStore: Store, mode: NavigationMode) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.selectedStore = selectedStore
        self.path = []
        
        var initialState = NavigationState(startLocation: nil, endLocation: nil, mode: mode)
        initialState.setLocation(selectedStore, for: mode)
        self._navigationState = State(initialValue: initialState)
        
        if mode == .fromHere {
            self._startLocationText = State(initialValue: selectedStore.name)
            self._destinationText = State(initialValue: "")
            self._activeField = State(initialValue: .destination)
        } else {
            self._startLocationText = State(initialValue: "")
            self._destinationText = State(initialValue: selectedStore.name)
            self._activeField = State(initialValue: .startLocation)
        }
    }
    
    var filteredStores: [Store] {
        var stores = viewModel.allStores
        
        if let selectedCat = selectedCategory {
            stores = stores.filter { $0.category == selectedCat }
            let currentSearchText = getCurrentSearchText()
            if !currentSearchText.isEmpty {
                stores = stores.filter { $0.name.lowercased().contains(currentSearchText.lowercased()) }
            }
        } else {
            let currentSearchText = getCurrentSearchText()
            if !currentSearchText.isEmpty {
                stores = stores.filter { $0.name.lowercased().contains(currentSearchText.lowercased()) }
            }
        }
        
        return stores
    }
    
    private func getCurrentSearchText() -> String {
        switch activeField {
        case .startLocation:
            if navigationState.startLocation == nil {
                return startLocationText
            } else {
                return ""
            }
        case .destination:
            if navigationState.endLocation == nil {
                return destinationText
            } else {
                return ""
            }
        case .none:
            return ""
        }
    }
    
    var canReverse: Bool {
        let hasStartLocation = navigationState.startLocation != nil
        let hasEndLocation = navigationState.endLocation != nil
        return hasStartLocation || hasEndLocation
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 36, height: 5)
                        .cornerRadius(3)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    
                    HStack {
                        Text("Navigation")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            isPresented = false
                            
                            navigationState.startLocation = nil
                            navigationState.endLocation = nil
                            
                            showDirectionView = false
                            
                            // Clear the selected store to dismiss TenantDetailModalView
                            viewModel.selectedStore = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .background(Color(.systemBackground))
                
                navigationContentView
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .alert("Same Location Selected", isPresented: $showingSameLocationAlert) {
            Button("OK") { }
        } message: {
            Text("Starting location and destination cannot be the same. Please select a different location.")
        }
        .fullScreenCover(isPresented: $showDirectionView) {
        if let start = navigationState.startLocation,
           let end = navigationState.endLocation {
            DirectionView(
                startLocation: start,
                destinationStore: end,
                viewModel: viewModel,
                onDismiss: {
                    // Clear the selected store when dismissing DirectionView
                    viewModel.selectedStore = nil
                    viewModel.exitSearch() // This closes the search view
                },
                onDismissNavigationModal: {
                    showDirectionView = false
                },
                onDismissTenantModal: {
                    // Clear the selected store to dismiss TenantDetailModalView
                    viewModel.selectedStore = nil
                }
            )
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
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.blue)
                        
                        TextField("Search starting location", text: $startLocationText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .onTapGesture {
                                activeField = .startLocation
                            }
                            .onChange(of: startLocationText) { _, newValue in
                                activeField = .startLocation
                                if let currentStore = navigationState.startLocation {
                                    if newValue != currentStore.name {
                                        navigationState.startLocation = nil
                                    }
                                }
                            }
                        
                        Spacer()
                        
                        if navigationState.startLocation != nil {
                            Button(action: {
                                navigationState.startLocation = nil
                                startLocationText = ""
                                activeField = .startLocation
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                        
                        TextField("Search destination", text: $destinationText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .onTapGesture {
                                activeField = .destination
                            }
                            .onChange(of: destinationText) { _, newValue in
                                activeField = .destination
                                if let currentStore = navigationState.endLocation {
                                    if newValue != currentStore.name {
                                        navigationState.endLocation = nil
                                    }
                                }
                            }
                        
                        Spacer()
                        
                        if navigationState.endLocation != nil {
                            Button(action: {
                                navigationState.endLocation = nil
                                destinationText = ""
                                activeField = .destination
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
                
                Button(action: {
                    if canReverse {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if navigationState.startLocation != nil && navigationState.endLocation == nil {
                                // Move start to destination
                                navigationState.endLocation = navigationState.startLocation
                                navigationState.startLocation = nil
                                destinationText = startLocationText
                                startLocationText = ""
                                activeField = .startLocation
                            } else if navigationState.endLocation != nil && navigationState.startLocation == nil {
                                // Move destination to start
                                navigationState.startLocation = navigationState.endLocation
                                navigationState.endLocation = nil
                                startLocationText = destinationText
                                destinationText = ""
                                activeField = .destination
                            } else if navigationState.startLocation != nil && navigationState.endLocation != nil {
                                // Both fields are filled - swap them
                                let tempLocation = navigationState.startLocation
                                let tempText = startLocationText
                                
                                navigationState.startLocation = navigationState.endLocation
                                startLocationText = destinationText
                                
                                navigationState.endLocation = tempLocation
                                destinationText = tempText
                            }
                        }
                    }
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
            
            Button(action: {
                if navigationState.startLocation != nil,
                   navigationState.endLocation != nil {
                    showDirectionView = true
                }
            }) {
                HStack {
                    Text("GO")
                        .font(.system(size: 16, weight: .semibold))
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    (navigationState.startLocation != nil && navigationState.endLocation != nil)
                    ? customBlueColor
                    : Color(.systemGray3)
                )
                .cornerRadius(12)
            }
            .disabled(navigationState.startLocation == nil || navigationState.endLocation == nil)
            .padding(.horizontal)
            .padding(.bottom, 16)
            
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
            
            List(filteredStores) { store in
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
    }
    
    private func selectLocation(_ store: Store) {
        if activeField == .startLocation || (navigationState.startLocation == nil && navigationState.endLocation != nil) {
            if navigationState.endLocation?.id == store.id {
                showingSameLocationAlert = true
                return
            }
            navigationState.startLocation = store
            startLocationText = store.name
            activeField = .destination
        } else {
            if navigationState.startLocation?.id == store.id {
                showingSameLocationAlert = true
                return
            }
            navigationState.endLocation = store
            destinationText = store.name
            activeField = .startLocation
        }
    }
}
