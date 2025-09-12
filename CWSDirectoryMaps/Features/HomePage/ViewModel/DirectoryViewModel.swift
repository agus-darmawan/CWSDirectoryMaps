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
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    @Published var selectedStore: Store? = nil
    
    @Published var showDirectionModal = false
    @Published var selectedStoreForDirection: Store?
    
    @Published var fromLocation: String = ""
    @Published var toLocation: String = ""
    @Published var shouldNavigateToDirection = false
    
    @Published var calculatedPath: [(point: CGPoint, label: String)] = []
    
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
                        self?.loadMockData() // Fallback to mock data on error
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
            loadMockData()
        }
    }
    
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
        
        print("\n--- [Debug] Comparing API/mock store list against normalized map data ---")
        
        for store in self.allStores {
            let normalizedStoreName = normalize(name: store.name)
            if let originalMapName = normalizedMapLocations[normalizedStoreName] {
                print("  ✅ Match Found: Store '\(store.name)' (as '\(normalizedStoreName)') matches map location '\(originalMapName)'.")
            } else {
                print("  ❌ MISSING: Store '\(store.name)' (as '\(normalizedStoreName)') was NOT found in the normalized map locations.")
            }
        }
        
        print("--- [Debug Check] Verification complete ---\n")
    }
    
    private func normalize(name: String) -> String {
        var normalized = name.lowercased()
        
        if let range = normalized.range(of: "-\\d+$", options: .regularExpression) {
            normalized.removeSubrange(range)
        }
        
        normalized = normalized.replacingOccurrences(of: " ", with: "")
        normalized = normalized.replacingOccurrences(of: "-", with: "")
        normalized = normalized.replacingOccurrences(of: "_", with: "")
        normalized = normalized.replacingOccurrences(of: "&", with: "")
        normalized = normalized.replacingOccurrences(of: ",", with: "")
        
        return normalized
    }
    
    private func loadMockData() {
        self.allStores = [
            Store(
                name: "One Love Bespoke",
                category: .shop,
                imageName: "store_logo_placeholder",
                subcategory: "Fashion, Watches & Jewelry",
                description: "One Love Bespoke is a dedicated atelier where couples can bring their dream wedding ring to life. They specialize in creating handcrafted rings tailored precisely to your unique preferences. Each piece is meticulously crafted with attention to detail, using premium materials and traditional techniques passed down through generations.",
                location: "Level 1, Unit 116",
                website: "https://onelovebespoke.com",
                phone: "+62 817 0350 3999",
                hours: "10:00AM - 10:00PM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Adidas",
                category: .shop,
                imageName: "store_logo_placeholder",
                subcategory: "Sports & Lifestyle",
                description: "Adidas is a global leader in sporting goods, offering premium athletic footwear, apparel, and accessories for all sports and lifestyle needs. Adidas is a global leader in sporting goods, offering premium athletic footwear, apparel, and accessories for all sports and lifestyle needs. Adidas is a global leader in sporting goods, offering premium athletic footwear, apparel, and accessories for all sports and lifestyle needs. Adidas is a global leader in sporting goods, offering premium athletic footwear, apparel, and accessories for all sports and lifestyle needs. Adidas is a global leader in sporting goods, offering premium athletic footwear, apparel, and accessories for all sports and lifestyle needs. Adidas is a global leader in sporting goods, offering premium athletic footwear, apparel, and accessories for all sports and lifestyle needs.",
                location: "Level 1, Unit 101",
                website: "https://adidas.com",
                phone: "+62 21 1234 5678",
                hours: "10:00AM - 10:00PM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Aigner",
                category: .shop,
                imageName: "store_logo_placeholder",
                subcategory: "Luxury Fashion",
                description: "Aigner offers luxury leather goods, handbags, and fashion accessories with distinctive German craftsmanship and timeless elegance.",
                location: "Level 1, Unit 102",
                website: "https://aigner.com",
                phone: "+62 21 2345 6789",
                hours: "10:00AM - 10:00PM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Alba",
                category: .shop,
                imageName: "store_logo_placeholder",
                subcategory: "Watches & Timepieces",
                description: "Alba provides stylish and reliable timepieces for everyday wear, combining modern design with Japanese precision.",
                location: "Level 1, Unit 103",
                website: "https://alba-watch.com",
                phone: "+62 21 3456 7890",
                hours: "10:00AM - 10:00PM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Aldo",
                category: .shop,
                imageName: "store_logo_placeholder",
                subcategory: "Footwear & Accessories",
                description: "Aldo offers trendy footwear and accessories for men and women, featuring contemporary designs at accessible prices.",
                location: "Level 1, Unit 104",
                website: "https://aldoshoes.com",
                phone: "+62 21 4567 8901",
                hours: "10:00AM - 10:00PM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Starbucks",
                category: .fnb,
                imageName: "store_logo_placeholder",
                subcategory: "Coffee & Beverages",
                description: "Starbucks serves premium coffee, handcrafted beverages, and light bites in a welcoming atmosphere perfect for meetings or relaxation.",
                location: "Level 1, Unit 105",
                website: "https://starbucks.com",
                phone: "+62 21 6789 0123",
                hours: "07:00AM - 11:00PM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "McDonald's",
                category: .fnb,
                imageName: "store_logo_placeholder",
                subcategory: "Fast Food",
                description: "McDonald's offers quick service meals, burgers, fries, and beverages loved by families worldwide.",
                location: "Level 1, Unit 106",
                website: "https://mcdonalds.com",
                phone: "+62 21 7890 1234",
                hours: "24 Hours",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "ATM Center",
                category: .others,
                imageName: "store_logo_placeholder",
                subcategory: "Banking Services",
                description: "ATM Center provides 24-hour banking services with multiple bank options for your convenience.",
                location: "Level 1, Lobby",
                website: nil,
                phone: nil,
                hours: "24 Hours",
                detailImageName: "store_logo_placeholder"
            ),
            // Lobbies
            Store(
                name: "Main Lobby",
                category: .lobbies,
                imageName: "store_logo_placeholder",
                subcategory: "Information Center",
                description: "",
                location: "Ground Floor, Central",
                website: nil,
                phone: nil,
                hours: "06:00AM - 12:00AM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "North Entrance Lobby",
                category: .lobbies,
                imageName: "store_logo_placeholder",
                subcategory: "Main Entrance",
                description: "",
                location: "Ground Floor, North Wing",
                website: nil,
                phone: nil,
                hours: "24 Hours",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "South Entrance Lobby",
                category: .lobbies,
                imageName: "store_logo_placeholder",
                subcategory: "Main Entrance",
                description: "",
                location: "Ground Floor, South Wing",
                website: nil,
                phone: nil,
                hours: "24 Hours",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Restroom - Level 1 North",
                category: .facilities,
                imageName: "store_logo_placeholder",
                subcategory: "Public Facilities",
                description: "Public restroom facilities with baby changing room available",
                location: "Level 1, North Wing",
                website: nil,
                phone: nil,
                hours: "06:00AM - 12:00AM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Restroom - Level 1 South",
                category: .facilities,
                imageName: "store_logo_placeholder",
                subcategory: "Public Facilities",
                description: "Public restroom facilities with baby changing room available",
                location: "Level 1, Near Food Court",
                website: nil,
                phone: nil,
                hours: "06:00AM - 12:00AM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Restroom - Level 2 East",
                category: .facilities,
                imageName: "store_logo_placeholder",
                subcategory: "Public Facilities",
                description: "Public restroom facilities with baby changing room available",
                location: "Level 2, East Wing",
                website: nil,
                phone: nil,
                hours: "06:00AM - 12:00AM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Restroom - Level 2 West",
                category: .facilities,
                imageName: "store_logo_placeholder",
                subcategory: "Public Facilities",
                description: "Public restroom facilities with baby changing room available",
                location: "Level 2, Near Cinema",
                website: nil,
                phone: nil,
                hours: "06:00AM - 12:00AM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Restroom - Level 3",
                category: .facilities,
                imageName: "store_logo_placeholder",
                subcategory: "Public Facilities",
                description: "Public restroom facilities with baby changing room available",
                location: "Level 3, Central Area",
                website: nil,
                phone: nil,
                hours: "06:00AM - 12:00AM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Restroom - Ground Floor",
                category: .facilities,
                imageName: "store_logo_placeholder",
                subcategory: "Public Facilities",
                description: "Public restroom facilities with baby changing room available",
                location: "Ground Floor, Main Lobby",
                website: nil,
                phone: nil,
                hours: "06:00AM - 12:00AM",
                detailImageName: "store_logo_placeholder"
            ),
            // Information Desks (Wheelchair, Charging Station, Baby Stroller available) - Category: facilities
            Store(
                name: "Information Desk - Main Lobby",
                category: .facilities,
                imageName: "store_logo_placeholder",
                subcategory: "Customer Service",
                description: "Main information desk providing wheelchair rental, charging stations, and baby stroller rental services",
                location: "Ground Floor, Main Lobby",
                website: nil,
                phone: "+62 21 5555 0001",
                hours: "09:00AM - 10:00PM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Information Desk - Level 1",
                category: .facilities,
                imageName: "store_logo_placeholder",
                subcategory: "Customer Service",
                description: "Information desk providing wheelchair rental, charging stations, and baby stroller rental services",
                location: "Level 1, Central Area",
                website: nil,
                phone: "+62 21 5555 0002",
                hours: "09:00AM - 10:00PM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Information Desk - Level 2",
                category: .facilities,
                imageName: "store_logo_placeholder",
                subcategory: "Customer Service",
                description: "Information desk providing wheelchair rental, charging stations, and baby stroller rental services",
                location: "Level 2, Food Court Area",
                website: nil,
                phone: "+62 21 5555 0003",
                hours: "09:00AM - 10:00PM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Information Desk - Level 3",
                category: .facilities,
                imageName: "store_logo_placeholder",
                subcategory: "Customer Service",
                description: "Information desk providing wheelchair rental, charging stations, and baby stroller rental services",
                location: "Level 3, Entertainment Area",
                website: nil,
                phone: "+62 21 5555 0004",
                hours: "09:00AM - 10:00PM",
                detailImageName: "store_logo_placeholder"
            ),
            // Other Facilities
            Store(
                name: "Elevator Bank A",
                category: .facilities,
                imageName: "store_logo_placeholder",
                subcategory: "Vertical Transportation",
                description: "",
                location: "Central Area, All Levels",
                website: nil,
                phone: nil,
                hours: "06:00AM - 12:00AM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Elevator Bank B",
                category: .facilities,
                imageName: "store_logo_placeholder",
                subcategory: "Vertical Transportation",
                description: "",
                location: "East Wing, All Levels",
                website: nil,
                phone: nil,
                hours: "06:00AM - 12:00AM",
                detailImageName: "store_logo_placeholder"
            )
        ]
    }
    
    private func setupFiltering() {
        Publishers.CombineLatest3($searchText, $selectedCategory, $selectedStore)
            .map { [weak self] (text, category, store) -> [Store] in
                guard let self = self else { return [] }
                
                var storesToFilter = self.allStores
                if let selectedCat = category {
                    storesToFilter = self.allStores.filter { $0.category == selectedCat }
                    
                    print("🔍 Filtering by category: \(selectedCat.rawValue)")
                    print("📊 Total stores: \(self.allStores.count)")
                    print("📊 Stores in category \(selectedCat.rawValue): \(storesToFilter.count)")
                    
                    for store in self.allStores {
                        print("🏪 Store: \(store.name) - Category: \(store.category.rawValue)")
                    }
                }
                
                if text.isEmpty {
                    return storesToFilter
                }
                
                let searchQuery = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
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
                
                if searchQuery.contains("wheelchair") ||
                    "wheelchair".hasPrefix(searchQuery) && searchQuery.count >= 3 {
                    let informationDesks = self.allStores.filter { store in
                        store.category == .facilities && store.name.lowercased().contains("information")
                    }
                    print("♿ Special search: Wheelchair - Found \(informationDesks.count) information")
                    return informationDesks
                }
                
                if (searchQuery.contains("charging") && searchQuery.contains("station")) ||
                    ("charging station".hasPrefix(searchQuery) && searchQuery.count >= 3) ||
                    ("chargingstation".hasPrefix(searchQuery) && searchQuery.count >= 3) {
                    let informationDesks = self.allStores.filter { store in
                        store.category == .facilities && store.name.lowercased().contains("information")
                    }
                    print("🔌 Special search: Charging station - Found \(informationDesks.count) information")
                    return informationDesks
                }
                
                if (searchQuery.contains("baby") && searchQuery.contains("stroller")) ||
                    ("baby stroller".hasPrefix(searchQuery) && searchQuery.count >= 3) ||
                    ("babystroller".hasPrefix(searchQuery) && searchQuery.count >= 3) {
                    let informationDesks = self.allStores.filter { store in
                        store.category == .facilities && store.name.lowercased().contains("information")
                    }
                    print("🍼🛒 Special search: Baby stroller - Found \(informationDesks.count) information")
                    return informationDesks
                }
                
                if searchQuery.contains("informant") || searchQuery.contains("information") {
                    let informationDesks = self.allStores.filter { store in
                        store.category == .facilities && store.name.lowercased().contains("information")
                    }
                    print("ℹ️ Special search: Information - Found \(informationDesks.count) information")
                    return informationDesks
                }
                
                if searchQuery.contains("restroom") {
                    let restrooms = self.allStores.filter { store in
                        store.category == .facilities && store.name.lowercased().contains("restroom")
                    }
                    print("🚻 Special search: Restroom - Found \(restrooms.count) restrooms")
                    return restrooms
                }
                
                let filteredResults = storesToFilter.filter { store in
                    let storeName = store.name.lowercased()
                    let storeContainsQuery = storeName.contains(searchQuery)
                    
                    let isSpecialSearchTerm = storeName.contains("wheelchair") ||
                    storeName.contains("charging station") ||
                    storeName.contains("baby stroller") ||
                    storeName.contains("baby room") ||
                    storeName.contains("babyroom") ||
                    storeName.contains("babys room") ||
                    storeName.contains("baby") ||
                    storeName.contains("babys")
                    
                    return storeContainsQuery && !isSpecialSearchTerm
                }
                
                return filteredResults
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
    
    func selectStore(_ store: Store) {
        selectedStore = store
        searchText = store.name
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
}
