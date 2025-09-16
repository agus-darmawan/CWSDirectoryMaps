//
//  DirectoryViewModel.swift
//  CWSDirectoryMaps
//
//  Production-ready version with enhanced navigation search support and state management
//

import Foundation
import Combine

class DirectoryViewModel: ObservableObject {
    
    @Published var allStores: [Store] = []
    @Published var filteredStores: [Store] = []
    
    @Published var searchText: String = ""
    @Published var selectedCategory: StoreCategory? = nil
    
    @Published var isSearching: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    @Published var selectedStore: Store? = nil
    
    @Published var showDirectionModal = false
    @Published var selectedStoreForDirection: Store?
    
    @Published var fromLocation: String = ""
    @Published var toLocation: String = ""
    @Published var shouldNavigateToDirection = false
    
    @Published var calculatedPath: [(point: CGPoint, label: String)] = []
    
    // FIXED: Add navigation state tracking
    @Published var isNavigating: Bool = false
    
    private let storeService = StoreService()
    private var cancellables = Set<AnyCancellable>()
    
    private var hasVerifiedOnce = false
    
    var dataManager: DataManager?
    
    private let useAPI = APIConfiguration.shared.useAPI
    
    init() {
        setupFiltering()
    }
    
    func setup(dataManager: DataManager) {
        self.dataManager = dataManager
        // Guard against re-loading if the view re-appears
        if allStores.isEmpty {
            refreshData()
        }
    }
    
    // MARK: - Navigation State Management
    
    func startNavigation() {
        isNavigating = true
        // Clear search when starting navigation
        clearSearchForNavigation()
    }
    
    func endNavigation() {
        isNavigating = false
        // Reset search state when ending navigation
        resetSearchState()
    }
    
    private func clearSearchForNavigation() {
        // Only clear search UI, keep stores loaded
        searchText = ""
        isSearching = false
        selectedCategory = nil
        selectedStore = nil
    }
    
    private func resetSearchState() {
        // Full reset when ending navigation
        searchText = ""
        isSearching = false
        selectedCategory = nil
        selectedStore = nil
        showDirectionModal = false
        selectedStoreForDirection = nil
        shouldNavigateToDirection = false
    }
    
    // PUBLIC helper to clear all search fields (callable from views)
    func clearNavigationSearch() {
        resetSearchState()
        fromLocation = ""
        toLocation = ""
    }
    
    // MARK: - Data Loading
    
    private func loadStoresFromAPI() {
        // Ensure dataManager is available before proceeding
        guard let dataManager = self.dataManager else {
            print("❌ Error: DataManager not available.")
            self.errorMessage = "DataManager not available."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        storeService.fetchAllFacilitiesWithDetails()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        print("❌ API Error: \(error)")
                        // Note: Removed fallback to mock data - handle errors appropriately in production
                    }
                },
                receiveValue: { [weak self] facilitiesWithDetails in
                    guard let self = self else { return }
                    
                    var loadedStores: [Store] = []
                    
                    // Now we are sure dataManager.allLocations is ready
                    let mapLocations = dataManager.allLocations
                    
                    for facilityWithDetails in facilitiesWithDetails {
                        let store = self.storeService.convertFacilityWithDetailsToStore(facilityWithDetails, mapLocations: mapLocations)
                        loadedStores.append(store)
                    }
                    
                    self.allStores = loadedStores
                    self.debug_checkStoresAgainstMap()
                    print("✅ Loaded and processed \(loadedStores.count) stores from API.")
                    print(Date())
                }
            )
            .store(in: &cancellables)
    }
    
    func refreshData() {
        if useAPI {
            loadStoresFromAPI()
        } else {
            // In production, you might want to handle offline scenarios
            self.errorMessage = "API is disabled. Please enable API access."
            print("⚠️ API access is disabled")
        }
    }
    
    // MARK: - Debug and Verification
    
    private func debug_checkStoresAgainstMap() {
        guard !hasVerifiedOnce else { return }
        hasVerifiedOnce = true
        
        guard let dataManager = self.dataManager, !dataManager.allLocations.isEmpty else {
            print("[Debug Check] DataManager has no locations. Skipping check.")
            return
        }
        
        var normalizedMapLocations: [String: String] = [:]
        for location in dataManager.allLocations {
            let normalizedName = normalize(name: location.name)
            normalizedMapLocations[normalizedName] = location.name
        }
        
        print("\n--- [Debug] Comparing API store list against normalized map data ---")
        
        var matchedCount = 0
        var unmatchedCount = 0
        
        for store in self.allStores {
            let normalizedStoreName = normalize(name: store.name)
            if let originalMapName = normalizedMapLocations[normalizedStoreName] {
                print("  ✅ Match Found: Store '\(store.name)' (as '\(normalizedStoreName)') matches map location '\(originalMapName)'.")
                matchedCount += 1
            } else {
                print("  ❌ MISSING: Store '\(store.name)' (as '\(normalizedStoreName)') was NOT found in the normalized map locations.")
                unmatchedCount += 1
            }
        }
        
        print("--- [Debug Check] Summary: \(matchedCount) matched, \(unmatchedCount) unmatched ---\n")
    }
    
    private func normalize(name: String) -> String {
        var normalized = name.lowercased()
        
        // Remove trailing numbers (e.g., "store-1" becomes "store")
        if let range = normalized.range(of: "-\\d+$", options: .regularExpression) {
            normalized.removeSubrange(range)
        }
        
        // Remove common separators and symbols
        normalized = normalized.replacingOccurrences(of: " ", with: "")
        normalized = normalized.replacingOccurrences(of: "-", with: "")
        normalized = normalized.replacingOccurrences(of: "_", with: "")
        normalized = normalized.replacingOccurrences(of: "&", with: "")
        normalized = normalized.replacingOccurrences(of: ",", with: "")
        normalized = normalized.replacingOccurrences(of: ".", with: "")
        normalized = normalized.replacingOccurrences(of: "'", with: "")
        
        return normalized
    }
    
    // MARK: - Core Filtering Logic
    
    func filterStores(text: String, category: StoreCategory?, selectedStore: Store?) -> [Store] {
        var storesToFilter = self.allStores
        
        // Apply category filter first
        if let selectedCat = category {
            storesToFilter = self.allStores.filter { $0.category == selectedCat }
            
            print("🔍 Filtering by category: \(selectedCat.rawValue)")
            print("📊 Total stores: \(self.allStores.count)")
            print("📊 Stores in category \(selectedCat.rawValue): \(storesToFilter.count)")
        }
        
        // If no search text, return category-filtered results
        if text.isEmpty {
            return storesToFilter
        }
        
        let searchQuery = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle special search cases for facilities
        if let specialResults = handleSpecialSearchCases(searchQuery: searchQuery) {
            print("🔍 Special search case handled: \(searchQuery)")
            return specialResults
        }
        
        // Regular search through store names
        let filteredResults = storesToFilter.filter { store in
            let storeName = store.name.lowercased()
            let storeContainsQuery = storeName.contains(searchQuery)
            
            // Exclude stores that match special facility terms to avoid confusion
            let isSpecialSearchTerm = containsSpecialFacilityTerms(storeName)
            
            return storeContainsQuery && !isSpecialSearchTerm
        }
        
        print("🔍 Regular search for '\(searchQuery)': found \(filteredResults.count) results")
        return filteredResults
    }
    
    // MARK: - Special Search Cases
    
    private func handleSpecialSearchCases(searchQuery: String) -> [Store]? {
        
        // Baby room / Baby changing room
        if (searchQuery.contains("baby") && (searchQuery.contains("room") || searchQuery.contains("changing"))) ||
            searchQuery.hasPrefix("babyroom") || searchQuery.hasPrefix("baby room") ||
            ("baby room".hasPrefix(searchQuery) && searchQuery.count >= 3) ||
            ("babyroom".hasPrefix(searchQuery) && searchQuery.count >= 3) {
            
            let restrooms = self.allStores.filter { store in
                store.category == .facilities && store.name.lowercased().contains("restroom")
            }
            print("🍼 Special search: Baby's room - Found \(restrooms.count) restrooms")
            return restrooms
        }
        
        // Wheelchair
        if searchQuery.contains("wheelchair") ||
            ("wheelchair".hasPrefix(searchQuery) && searchQuery.count >= 3) {
            
            let informationDesks = self.allStores.filter { store in
                store.category == .facilities && store.name.lowercased().contains("information")
            }
            print("♿ Special search: Wheelchair - Found \(informationDesks.count) information desks")
            return informationDesks
        }
        
        // Charging station
        if (searchQuery.contains("charging") && searchQuery.contains("station")) ||
            ("charging station".hasPrefix(searchQuery) && searchQuery.count >= 3) ||
            ("chargingstation".hasPrefix(searchQuery) && searchQuery.count >= 3) {
            
            let informationDesks = self.allStores.filter { store in
                store.category == .facilities && store.name.lowercased().contains("information")
            }
            print("🔌 Special search: Charging station - Found \(informationDesks.count) information desks")
            return informationDesks
        }
        
        // Baby stroller
        if (searchQuery.contains("baby") && searchQuery.contains("stroller")) ||
            ("baby stroller".hasPrefix(searchQuery) && searchQuery.count >= 3) ||
            ("babystroller".hasPrefix(searchQuery) && searchQuery.count >= 3) {
            
            let informationDesks = self.allStores.filter { store in
                store.category == .facilities && store.name.lowercased().contains("information")
            }
            print("🍼🛒 Special search: Baby stroller - Found \(informationDesks.count) information desks")
            return informationDesks
        }
        
        // Information / Information desk
        if searchQuery.contains("informant") || searchQuery.contains("information") {
            let informationDesks = self.allStores.filter { store in
                store.category == .facilities && store.name.lowercased().contains("information")
            }
            print("ℹ️ Special search: Information - Found \(informationDesks.count) information desks")
            return informationDesks
        }
        
        // Restroom / Toilet
        if searchQuery.contains("restroom") || searchQuery.contains("toilet") {
            let restrooms = self.allStores.filter { store in
                store.category == .facilities && store.name.lowercased().contains("restroom")
            }
            print("🚻 Special search: Restroom - Found \(restrooms.count) restrooms")
            return restrooms
        }
        
        // ATM / Banking
        if searchQuery.contains("atm") || searchQuery.contains("bank") {
            let atmCenters = self.allStores.filter { store in
                store.name.lowercased().contains("atm") || store.name.lowercased().contains("bank")
            }
            print("💳 Special search: ATM/Banking - Found \(atmCenters.count) locations")
            return atmCenters
        }
        
        // Elevator
        if searchQuery.contains("elevator") || searchQuery.contains("lift") {
            let elevators = self.allStores.filter { store in
                store.category == .facilities &&
                (store.name.lowercased().contains("elevator") || store.name.lowercased().contains("lift"))
            }
            print("🛗 Special search: Elevator - Found \(elevators.count) elevators")
            return elevators
        }
        
        return nil
    }
    
    private func containsSpecialFacilityTerms(_ storeName: String) -> Bool {
        let specialTerms = [
            "wheelchair", "charging station", "baby stroller", "baby room",
            "babyroom", "babys room", "baby", "babys", "information",
            "restroom", "toilet", "atm", "elevator", "lift"
        ]
        
        return specialTerms.contains { storeName.contains($0) }
    }
    
    // MARK: - Public Filtering Methods
    
    // Provide a convenience method for NavigationModalView to call the same filtering
    func filteredStoresForNavigation(query: String, category: StoreCategory?) -> [Store] {
        return filterStores(text: query, category: category, selectedStore: nil)
    }
    
    // MARK: - Setup Combine Filtering
    
    private func setupFiltering() {
        Publishers.CombineLatest3($searchText, $selectedCategory, $selectedStore)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main) // Add debounce for better performance
            .map { [weak self] (text, category, store) -> [Store] in
                guard let self = self else { return [] }
                return self.filterStores(text: text, category: category, selectedStore: store)
            }
            .assign(to: \.filteredStores, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - User Interaction Methods
    
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
        selectedCategory = nil
    }
    
    func exitSearch() {
        // Only exit search if not navigating
        if !isNavigating {
            isSearching = false
            searchText = ""
            selectedCategory = nil
            selectedStore = nil
        } else {
            // If navigating, just clear the search text but keep isSearching true
            searchText = ""
        }
    }
    
    func selectStore(_ store: Store) {
        selectedStore = store
        searchText = store.name
    }
    
    // MARK: - Navigation Methods
    
    /// Set up selection coming from NavigationModalView
    func applyNavigationSelection(_ store: Store, isStart: Bool) {
        selectedStore = store
        if isStart {
            fromLocation = store.name
        } else {
            toLocation = store.name
        }
        // Clear the search text (so textfield bound to searchText becomes empty)
        searchText = ""
    }
    
    func showDirections(for store: Store) {
        selectedStoreForDirection = store
        showDirectionModal = true
    }
    
    func navigateToDirection() {
        if !fromLocation.isEmpty && !toLocation.isEmpty {
            shouldNavigateToDirection = true
        }
    }
    
    // MARK: - Navigation State Management
    
    func resetForNewNavigation() {
        // Reset only navigation-specific states, preserve loaded stores
        searchText = ""
        selectedCategory = nil
        selectedStore = nil
        showDirectionModal = false
        selectedStoreForDirection = nil
        fromLocation = ""
        toLocation = ""
        shouldNavigateToDirection = false
        calculatedPath = []
    }
    
    func handleEndRoute() {
        // Clear navigation states but keep the store data
        isNavigating = false
        resetForNewNavigation()
        
        // Reset to non-searching state
        isSearching = false
        
        print("🏁 Navigation ended - states reset")
    }
    
    // MARK: - Error Handling
    
    func retryDataLoad() {
        errorMessage = nil
        refreshData()
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Computed Properties
    
    var hasStores: Bool {
        return !allStores.isEmpty
    }
    
    var isLoadingOrEmpty: Bool {
        return isLoading || allStores.isEmpty
    }
    
    var shouldShowEmptyState: Bool {
        return !isLoading && allStores.isEmpty && errorMessage == nil
    }
    
    var shouldShowErrorState: Bool {
        return errorMessage != nil
    }
    
    // MARK: - Cleanup
    
    deinit {
        cancellables.removeAll()
    }
}
