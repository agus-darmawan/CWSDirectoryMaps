//
//  StoreService.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 01/09/25.
//

import Foundation
import Combine

class StoreService: ObservableObject {
    private let networkManager = NetworkManager.shared
    
    func fetchStores() -> AnyPublisher<[DetailDTO], APIError> {
        return networkManager.request(
            endpoint: .getDetails,
            responseType: [DetailDTO].self
        )
        .eraseToAnyPublisher()
    }
    
    func fetchStoreDetail(id: Int) -> AnyPublisher<DetailDTO, APIError> {
        return networkManager.request(
            endpoint: .getDetailById(id: id),
            responseType: [DetailDTO].self
        )
        .compactMap(\.first)
        .mapError { _ in APIError.notFound }
        .eraseToAnyPublisher()
    }
    
    func fetchFacilities() -> AnyPublisher<[FacilityDTO], APIError> {
        return networkManager.request(
            endpoint: .getFacilities,
            responseType: [FacilityDTO].self
        )
        .eraseToAnyPublisher()
    }
    
    func fetchFacilityDetail(id: Int) -> AnyPublisher<FacilityDTO, APIError> {
        return networkManager.request(
            endpoint: .getFacilityById(id: id),
            responseType: FacilityDTO.self
        )
        .eraseToAnyPublisher()
    }
    
    func fetchFacilityWithDetails(id: Int) -> AnyPublisher<FacilityWithDetailsDTO, APIError> {
        return networkManager.request(
            endpoint: .getFacilityWithDetails(id: id),
            responseType: FacilityWithDetailsDTO.self
        )
        .eraseToAnyPublisher()
    }
    
    func fetchAllFacilitiesWithDetails() -> AnyPublisher<[FacilityWithDetailsDTO], APIError> {
        return fetchFacilities()
            .flatMap { facilities -> AnyPublisher<[FacilityWithDetailsDTO], APIError> in
                let publishers = facilities.map { facility in
                    self.fetchFacilityWithDetails(id: facility.id)
                }
                
                return Publishers.MergeMany(publishers)
                    .collect()
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func fetchFacilityTypes() -> AnyPublisher<[FacilityTypeDTO], APIError> {
        return networkManager.request(
            endpoint: .getFacilityTypes,
            responseType: [FacilityTypeDTO].self
        )
        .eraseToAnyPublisher()
    }
    
    func fetchFacilityTypeDetail(id: Int) -> AnyPublisher<FacilityTypeDTO, APIError> {
        return networkManager.request(
            endpoint: .getFacilityTypeById(id: id),
            responseType: [FacilityTypeDTO].self
        )
        .compactMap(\.first)
        .mapError { _ in APIError.notFound }
        .eraseToAnyPublisher()
    }
    
    func fetchLocations() -> AnyPublisher<[LocationDTO], APIError> {
        return networkManager.request(
            endpoint: .getLocations,
            responseType: [LocationDTO].self
        )
        .eraseToAnyPublisher()
    }
    
    func fetchLocationDetail(id: Int) -> AnyPublisher<LocationDTO, APIError> {
        return networkManager.request(
            endpoint: .getLocationById(id: id),
            responseType: [LocationDTO].self
        )
        .compactMap(\.first)
        .mapError { _ in APIError.notFound }
        .eraseToAnyPublisher()
    }
    
    func fetchTenantCategories() -> AnyPublisher<[TenantCategoryDTO], APIError> {
        return networkManager.request(
            endpoint: .getTenantCategories,
            responseType: [TenantCategoryDTO].self
        )
        .eraseToAnyPublisher()
    }
    
    func fetchTenantCategoryDetail(id: Int) -> AnyPublisher<TenantCategoryDTO, APIError> {
        return networkManager.request(
            endpoint: .getTenantCategoryById(id: id),
            responseType: [TenantCategoryDTO].self
        )
        .compactMap(\.first)
        .mapError { _ in APIError.notFound }
        .eraseToAnyPublisher()
    }
    
    func convertFacilityWithDetailsToStore(_ facilityDTO: FacilityWithDetailsDTO, mapLocations: [Location]) -> Store {
        let category = mapTenantCategoryToStoreCategory(facilityDTO.tenantCategory?.name)
        let hours = formatHours(
            openTime: facilityDTO.detail?.openTime,
            closeTime: facilityDTO.detail?.closeTime
        )
        let location = facilityDTO.detail?.unit ?? formatLocation(facilityDTO.location)
        
        // --- New Logic to Find the Graph Label ---
        let normalizedFacilityName = normalize(name: facilityDTO.name)
        var foundGraphLabel: String? = nil
        
        // Find the first map location that matches the normalized facility name.
        if let matchedLocation = mapLocations.first(where: { normalize(name: $0.name) == normalizedFacilityName }) {
            // Construct the full, unique label (e.g., "ground_path_coach-1")
            foundGraphLabel = "\(matchedLocation.floor.fileName)_\(matchedLocation.name)"
//            print("Matched \(facilityDTO.name) to graph label: \(foundGraphLabel!)")
        }
        // --- End of New Logic ---

        return Store(
            id: String(facilityDTO.id),
            name: facilityDTO.name,
            category: category,
            imageName: facilityDTO.imagePath ?? "store_logo_placeholder",
            subcategory: facilityDTO.tenantCategory?.name ?? facilityDTO.facilityType.name,
            description: facilityDTO.detail?.description ?? "",
            location: location,
            website: facilityDTO.detail?.website,
            phone: facilityDTO.detail?.phone,
            hours: hours,
            detailImageName: facilityDTO.imagePath ?? "store_logo_placeholder",
            graphLabel: foundGraphLabel
        )
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
        
        return normalized
    }
    
    private func mapTenantCategoryToStoreCategory(_ tenantCategoryName: String?) -> StoreCategory {
        guard let name = tenantCategoryName?.lowercased() else {
            return .facilities
        }
        
        switch name {
        case "shop", "retail", "store":
            return .shop
        case "f&b", "food", "beverage", "restaurant", "cafe":
            return .fnb
        case "facilities", "facility":
            return .facilities
        case "lobbies", "lobby":
            return .lobbies
        default:
            return .others
        }
    }
    
    private func formatHours(openTime: String?, closeTime: String?) -> String {
        guard let open = openTime, let close = closeTime else {
            return "Operating hours not available"
        }
        return "\(open) - \(close)"
    }
    
    private func formatLocation(_ location: LocationDTO) -> String {
        return "Floor \(location.z), X: \(location.x), Y: \(location.y)"
    }
}
