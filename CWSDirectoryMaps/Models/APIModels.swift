//
//  APIModels.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 01/09/25.
//

import Foundation

struct DetailDTO: Identifiable, Codable {
    let id: Int
    let description: String?
    let phone: String?
    let website: String?
    let unit: String?
    let openTime: String?
    let closeTime: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case description
        case phone
        case website
        case unit
        case openTime
        case closeTime
    }
}

struct FacilityDTO: Identifiable, Codable {
    let id: Int
    let name: String
    let imagePath: String?
    let facilityTypeID: Int
    let tenantCategoryID: Int?
    let locationID: Int
    let detailID: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case imagePath
        case facilityTypeID
        case tenantCategoryID
        case locationID
        case detailID
    }
}

struct FacilityWithDetailsDTO: Identifiable, Codable {
    let id: Int
    let name: String
    let imagePath: String?
    let facilityType: FacilityTypeDTO
    let tenantCategory: TenantCategoryDTO?
    let location: LocationDTO
    let detail: DetailDTO?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case imagePath
        case facilityType
        case tenantCategory
        case location
        case detail
    }
}

struct FacilityTypeDTO: Identifiable, Codable {
    let id: Int
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
    }
}

struct LocationDTO: Identifiable, Codable {
    let id: Int
    let x: Double
    let y: Double
    let z: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case x
        case y
        case z
    }
}

struct TenantCategoryDTO: Identifiable, Codable {
    let id: Int
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
    }
}
