//
//  Store.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 28/08/25.
//

import Foundation

enum StoreCategory: String, CaseIterable, Identifiable {
    case shop = "Shop"
    case fnb = "F&B"
    case play = "Play"
    case others = "Others"
    
    var id: String { self.rawValue }
}

struct Store: Identifiable {
    let id = UUID()
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
}
