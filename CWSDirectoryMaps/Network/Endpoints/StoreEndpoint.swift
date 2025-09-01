//
//  StoreEndpoint.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 01/09/25.
//

import Foundation

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

enum StoreEndpoint {
    case getDetails
    case getDetailById(id: Int)
    
    case getFacilities
    case getFacilityById(id: Int)
    case getFacilityWithDetails(id: Int)
    
    case getFacilityTypes
    case getFacilityTypeById(id: Int)
    
    case getLocations
    case getLocationById(id: Int)
    
    case getTenantCategories
    case getTenantCategoryById(id: Int)
    
    var path: String {
        switch self {
        case .getDetails:
            return "/api/v1/details"
        case .getDetailById(let id):
            return "/api/v1/details/\(id)"
            
        case .getFacilities:
            return "/api/v1/facilities"
        case .getFacilityById(let id):
            return "/api/v1/facilities/\(id)"
        case .getFacilityWithDetails(let id):
            return "/api/v1/facilities/\(id)/with-details"
            
        case .getFacilityTypes:
            return "/api/v1/facility-types"
        case .getFacilityTypeById(let id):
            return "/api/v1/facility-types/\(id)"
            
        case .getLocations:
            return "/api/v1/locations"
        case .getLocationById(let id):
            return "/api/v1/locations/\(id)"
            
        case .getTenantCategories:
            return "/api/v1/tenant-categories"
        case .getTenantCategoryById(let id):
            return "/api/v1/tenant-categories/\(id)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getDetails, .getDetailById,
                .getFacilities, .getFacilityById, .getFacilityWithDetails,
                .getFacilityTypes, .getFacilityTypeById,
                .getLocations, .getLocationById,
                .getTenantCategories, .getTenantCategoryById:
            return .GET
        }
    }
    
    var body: Data? {
        return nil
    }
}
