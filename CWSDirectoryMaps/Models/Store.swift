//
//  Store.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 28/08/25.
//

import Foundation

enum StoreCategory: String, CaseIterable, Identifiable, Codable {
    case shop = "Shop"
    case fnb = "F&B"
    case others = "Others"
    case facilities = "Facilities"
    case lobbies = "Lobbies"
    
    var id: String { self.rawValue }
}

struct Store: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let category: StoreCategory
    let imageName: String
    let subcategory: String
    let description: String
    let location: String
    let website: String?
    let phone: String?
    let hours: String
    let detailImageName: String
    var graphLabel: String?
    
    var isFacility: Bool {
        return category == .facilities || category == .lobbies
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case imageName
        case subcategory
        case description
        case location
        case website
        case phone
        case hours
        case detailImageName
    }
    
    init(id: String = UUID().uuidString, name: String, category: StoreCategory, imageName: String, subcategory: String, description: String, location: String, website: String?, phone: String?, hours: String, detailImageName: String, graphLabel: String? = nil) { // <-- Add graphLabel here
        self.id = id
        self.name = name
        self.category = category
        self.imageName = imageName
        self.subcategory = subcategory
        self.description = description
        self.location = location
        self.website = website
        self.phone = phone
        self.hours = hours
        self.detailImageName = detailImageName
        self.graphLabel = graphLabel // <-- And assign it here
    }
}
