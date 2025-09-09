//
//  APIResponse.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 01/09/25.
//

import Foundation

struct APIResponse<T: Codable>: Codable {
    let data: T
    let message: String?
    let success: Bool?
    
    enum CodingKeys: String, CodingKey {
        case data
        case message
        case success
    }
}

struct APIListResponse<T: Codable>: Codable {
    let data: [T]
    let message: String?
    let success: Bool?
    let count: Int?
    
    enum CodingKeys: String, CodingKey {
        case data
        case message
        case success
        case count
    }
}
