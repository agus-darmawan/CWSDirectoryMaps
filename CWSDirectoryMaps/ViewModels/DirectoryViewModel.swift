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
                name: "Amazing Express",
                category: .play,
                imageName: "store_logo_placeholder",
                subcategory: "Family Entertainment",
                description: "Amazing Express offers thrilling rides and family-friendly entertainment experiences for visitors of all ages.",
                location: "Level 2, Unit 201",
                website: nil,
                phone: "+62 21 5678 9012",
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
                name: "Cinema XXI",
                category: .play,
                imageName: "store_logo_placeholder",
                subcategory: "Movies & Entertainment",
                description: "Cinema XXI provides the latest movie releases with premium sound and visual technology for the ultimate cinema experience.",
                location: "Level 3, Unit 301",
                website: "https://21cineplex.com",
                phone: "+62 21 8901 2345",
                hours: "10:00AM - 12:00AM",
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
            Store(
                name: "North Entrance",
                category: .facility,
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
                name: "South Entrance",
                category: .facility,
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
                name: "Main Lobby",
                category: .facility,
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
                name: "Restroom - Level 1",
                category: .facility,
                imageName: "store_logo_placeholder",
                subcategory: "Public Facilities",
                description: "",
                location: "Level 1, Near Food Court",
                website: nil,
                phone: nil,
                hours: "06:00AM - 12:00AM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Restroom - Level 2",
                category: .facility,
                imageName: "store_logo_placeholder",
                subcategory: "Public Facilities",
                description: "",
                location: "Level 2, Near Cinema",
                website: nil,
                phone: nil,
                hours: "06:00AM - 12:00AM",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Emergency Exit A",
                category: .facility,
                imageName: "store_logo_placeholder",
                subcategory: "Emergency Exit",
                description: "",
                location: "Level 1, West Wing",
                website: nil,
                phone: nil,
                hours: "24 Hours",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Emergency Exit B",
                category: .facility,
                imageName: "store_logo_placeholder",
                subcategory: "Emergency Exit",
                description: "",
                location: "Level 2, East Wing",
                website: nil,
                phone: nil,
                hours: "24 Hours",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Parking Entrance",
                category: .facility,
                imageName: "store_logo_placeholder",
                subcategory: "Vehicle Access",
                description: "",
                location: "Basement Level",
                website: nil,
                phone: nil,
                hours: "24 Hours",
                detailImageName: "store_logo_placeholder"
            ),
            Store(
                name: "Elevator Bank A",
                category: .facility,
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
                category: .facility,
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
