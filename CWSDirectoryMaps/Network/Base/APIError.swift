//
//  APIError.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 01/09/25.
//

import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError
    case decodingError
    case serverError(Int)
    case noData
    case unauthorized
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network connection error"
        case .decodingError:
            return "Failed to decode response"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .noData:
            return "No data received"
        case .unauthorized:
            return "Unauthorized access"
        case .notFound:
            return "Resource not found"
        }
    }
}