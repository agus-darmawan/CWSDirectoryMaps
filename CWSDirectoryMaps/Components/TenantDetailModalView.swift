//
//  TenantDetailModal.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 28/08/25.
//

import SwiftUI

struct TenantDetailModalView: View {
    let store: Store
    @ObservedObject var viewModel: DirectoryViewModel
    @Binding var isPresented: Bool
    @State private var showFullDescription = false
    @State private var showNavigationView = false
    @State private var navigationMode: NavigationMode? = nil
    @State private var navigationState = NavigationState(startLocation: nil, endLocation: nil, mode: .fromHere)
    @State private var startLocationText: String = ""
    @State private var destinationText: String = ""
    @State private var selectedCategory: StoreCategory? = nil
    @State private var showingSameLocationAlert: Bool = false
    @State private var activeField: ActiveField? = nil
    
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
        navigationState.startLocation != nil && navigationState.endLocation != nil
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
                        if showNavigationView {
                            Text("Navigation")
                                .font(.title2)
                                .fontWeight(.bold)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(store.subcategory)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            isPresented = false
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
                
                if showNavigationView {
                    navigationContentView
                } else {
                    storeDetailContentView
                }
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
    }
    
    private var storeDetailContentView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: {
                    navigationMode = .fromHere
                    navigationState = NavigationState(startLocation: store, endLocation: nil, mode: .fromHere)
                    startLocationText = store.name
                    destinationText = ""
                    activeField = .destination
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showNavigationView = true
                    }
                }) {
                    Text("From Here")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray))
                        .cornerRadius(8)
                }
                
                Button(action: {
                    navigationMode = .toHere
                    navigationState = NavigationState(startLocation: nil, endLocation: store, mode: .toHere)
                    startLocationText = ""
                    destinationText = store.name
                    activeField = .startLocation
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showNavigationView = true
                    }
                }) {
                    Text("To Here")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(customBlueColor)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
            
            if store.isFacility {
                facilityContentView
            } else {
                storeDetailScrollView
            }
        }
    }
    
    private var facilityContentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                AsyncImage(url: URL(string: store.detailImageName)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(store.detailImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .frame(height: 200)
                .clipped()
                .cornerRadius(12)
                .padding(.horizontal)
                
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "location.fill")
                            .frame(width: 24)
                            .foregroundColor(.primary)
                        
                        Text(store.location)
                            .font(.body)
                        
                        Spacer()
                    }
                    
                    if !store.hours.isEmpty {
                        HStack {
                            Image(systemName: "clock.fill")
                                .frame(width: 24)
                                .foregroundColor(.primary)
                            
                            Text(store.hours)
                                .font(.body)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var storeDetailScrollView: some View {
        ScrollView {
            VStack(spacing: 20) {
                AsyncImage(url: URL(string: store.detailImageName)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(store.detailImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .frame(height: 200)
                .clipped()
                .cornerRadius(12)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(showFullDescription ? store.description : String(store.description.prefix(150)) + (store.description.count > 150 ? "..." : ""))
                        .font(.body)
                        .lineLimit(showFullDescription ? nil : 3)
                    
                    if store.description.count > 150 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showFullDescription.toggle()
                            }
                        }) {
                            Text(showFullDescription ? "Show Less" : "Show More")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(customBlueColor)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "storefront.fill")
                            .frame(width: 24)
                            .foregroundColor(.primary)
                        
                        Text(store.location)
                            .font(.body)
                        
                        Spacer()
                    }
                    
                    if let website = store.website {
                        HStack {
                            Image(systemName: "globe")
                                .frame(width: 24)
                                .foregroundColor(.primary)
                            
                            Button(action: {
                                if let url = URL(string: website) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Click here")
                                    .font(.body)
                                    .foregroundColor(customBlueColor)
                                    .underline()
                            }
                            
                            Spacer()
                        }
                    }
                    
                    if let phone = store.phone {
                        HStack {
                            Image(systemName: "phone.fill")
                                .frame(width: 24)
                                .foregroundColor(.primary)
                            
                            Button(action: {
                                if let url = URL(string: "tel:\(phone)") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text(phone)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    HStack {
                        Image(systemName: "clock.fill")
                            .frame(width: 24)
                            .foregroundColor(.primary)
                        
                        Text(store.hours)
                            .font(.body)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
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
                            .font(.system(size: 24))
                        
                        if let startLocation = navigationState.startLocation {
                            Text(startLocation.name)
                                .foregroundColor(.primary)
                        } else {
                            TextField("Search starting location", text: $startLocationText)
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
                                    .font(.system(size: 20))
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    
                    Divider()
                        .frame(height: 1)
                    
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 24))
                        
                        if let endLocation = navigationState.endLocation {
                            Text(endLocation.name)
                                .foregroundColor(.primary)
                        } else {
                            TextField("Search destination", text: $destinationText)
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
                                    .font(.system(size: 20))
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Button(action: {
                    if canReverse {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            navigationState.reverseLocations()
                            let tempText = startLocationText
                            startLocationText = destinationText
                            destinationText = tempText
                        }
                    }
                }) {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 28))
                }
                .disabled(!canReverse)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
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
