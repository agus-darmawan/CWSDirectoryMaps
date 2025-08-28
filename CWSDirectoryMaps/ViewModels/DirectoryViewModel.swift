//
//  DirectoryViewModel.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 28/08/25.
//

import Foundation
import Combine

class DirectoryViewModel: ObservableObject {
    
    @Published var allStores: [Store] = []
    @Published var filteredStores: [Store] = []
    
    @Published var searchText: String = ""
    @Published var selectedCategory: StoreCategory? = nil
    
    @Published var isSearching: Bool = false
    
    @Published var selectedStore: Store? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadMockData()
        setupFiltering()
    }
    
    private func loadMockData() {
        self.allStores = [
            Store(name: "One Love Bespoke", category: .shop, imageName: "store_logo_placeholder"),
            Store(name: "Adidas", category: .shop, imageName: "store_logo_placeholder"),
            Store(name: "Aigner", category: .shop, imageName: "store_logo_placeholder"),
            Store(name: "Alba", category: .shop, imageName: "store_logo_placeholder"),
            Store(name: "Aldo", category: .shop, imageName: "store_logo_placeholder"),
            Store(name: "Amazing Express", category: .play, imageName: "store_logo_placeholder"),
            Store(name: "Starbucks", category: .fnb, imageName: "store_logo_placeholder"),
            Store(name: "McDonald's", category: .fnb, imageName: "store_logo_placeholder"),
            Store(name: "Cinema XXI", category: .play, imageName: "store_logo_placeholder"),
            Store(name: "ATM Center", category: .others, imageName: "store_logo_placeholder"),
        ]
    }
    
    private func setupFiltering() {
        Publishers.CombineLatest3($searchText, $selectedCategory, $selectedStore)
            .map { [weak self] (text, category, store) -> [Store] in
                guard let self = self else { return [] }
                
                if let selected = store {
                    return [selected]
                }
                
                var storesToFilter = self.allStores
                if let selectedCat = category {
                    storesToFilter = self.allStores.filter { $0.category == selectedCat }
                }
                
                if text.isEmpty {
                    return storesToFilter
                }
                
                return storesToFilter.filter { $0.name.lowercased().contains(text.lowercased()) }
            }
            .assign(to: \.filteredStores, on: self)
            .store(in: &cancellables)
    }
    
    func selectCategory(_ category: StoreCategory) {
        if selectedCategory == category {
            selectedCategory = nil
        } else {
            selectedCategory = category
        }
        selectedStore = nil
    }
    
    func clearSearch() {
        searchText = ""
        selectedStore = nil
    }
    
    func exitSearch() {
        isSearching = false
        searchText = ""
        selectedCategory = nil
        selectedStore = nil
    }
}
