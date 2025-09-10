//
//  TenantImageHelper.swift
//  CWSDirectoryMaps
//
//  Created by Darmawan on 09/09/25.
//


//
//  TenantImageHelper.swift
//  CWSDirectoryMaps
//
//  Helper for getting tenant images in navigation steps
//

import Foundation
import SwiftUI

class TenantImageHelper {
    
    private let config = APIConfiguration.shared
    private let dataManager: DataManager
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
    }
    
    // MARK: - Get Tenant Image for Step
    func getTenantImageForStep(_ step: EnhancedDirectionStep, from stores: [Store]) -> URL? {
        // Extract potential tenant names from step description
        let description = step.description.lowercased()
        let tenantNames = extractTenantNamesFromDescription(description)
        
        // Try to match with actual stores
        for tenantName in tenantNames {
            if let matchedStore = findMatchingStore(tenantName: tenantName, in: stores) {
                return constructImageURL(for: matchedStore)
            }
        }
        
        // Fallback: try to find nearest store based on coordinates
        if let nearestStore = findNearestStore(to: step.point, in: stores) {
            return constructImageURL(for: nearestStore)
        }
        
        return nil
    }
    
    // MARK: - Extract Tenant Names from Description
    private func extractTenantNamesFromDescription(_ description: String) -> [String] {
        var tenantNames: [String] = []
        
        // Common patterns in navigation descriptions
        let patterns = [
            "near (.+?)(?:\\s|$)",
            "at (.+?)(?:\\s|$)", 
            "towards (.+?)(?:\\s|$)",
            "past (.+?)(?:\\s|$)",
            "by (.+?)(?:\\s|$)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: description, range: NSRange(description.startIndex..., in: description))
                
                for match in matches {
                    if let range = Range(match.range(at: 1), in: description) {
                        let tenantName = String(description[range])
//                            .trimmingCharacters(in: .whitespacesAndPunctuationCharacters)
                        
                        if !tenantName.isEmpty && tenantName.count > 2 {
                            tenantNames.append(tenantName)
                        }
                    }
                }
            }
        }
        
        return tenantNames
    }
    
    // MARK: - Find Matching Store
    private func findMatchingStore(tenantName: String, in stores: [Store]) -> Store? {
        let normalizedTenantName = normalizeStoreName(tenantName)
        
        // Exact match first
        for store in stores {
            let normalizedStoreName = normalizeStoreName(store.name)
            if normalizedStoreName == normalizedTenantName {
                return store
            }
        }
        
        // Partial match
        for store in stores {
            let normalizedStoreName = normalizeStoreName(store.name)
            if normalizedStoreName.contains(normalizedTenantName) || 
               normalizedTenantName.contains(normalizedStoreName) {
                return store
            }
        }
        
        // Fuzzy match for common variations
        for store in stores {
            if isLikelyMatch(tenantName: normalizedTenantName, storeName: normalizeStoreName(store.name)) {
                return store
            }
        }
        
        return nil
    }
    
    // MARK: - Find Nearest Store
    private func findNearestStore(to point: CGPoint, in stores: [Store]) -> Store? {
        var nearestStore: Store? = nil
        var minDistance: Double = Double.infinity
        let maxDistance: Double = 100.0 // Maximum distance threshold
        
        for store in stores {
            // We would need to get store coordinates from the graph
            // For now, return nil as we don't have direct coordinate mapping
            // This could be enhanced if stores had coordinate information
        }
        
        return nearestStore
    }
    
    // MARK: - Construct Image URL
    private func constructImageURL(for store: Store) -> URL? {
        let imagePath = store.imageName.hasPrefix("/") ? store.imageName : "/images/" + store.imageName
        return URL(string: config.baseURL + imagePath)
    }
    
    // MARK: - Helper Methods
    private func normalizeStoreName(_ name: String) -> String {
        return name.lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
    }
    
    private func isLikelyMatch(tenantName: String, storeName: String) -> Bool {
        let tenantWords = Set(tenantName.components(separatedBy: " ").filter { $0.count > 2 })
        let storeWords = Set(storeName.components(separatedBy: " ").filter { $0.count > 2 })
        
        let intersection = tenantWords.intersection(storeWords)
        let union = tenantWords.union(storeWords)
        
        // Calculate Jaccard similarity
        let similarity = Double(intersection.count) / Double(union.count)
        return similarity > 0.5 // 50% similarity threshold
    }
}

// MARK: - Direction Steps Modal (Updated)
extension DirectionStepsModal {
    
    private func getTenantImageForStep(_ step: EnhancedDirectionStep) -> URL? {
        // Get the directory view model or stores data
        // This would need to be passed down or accessed through environment
        let stores: [Store] = [] // This should be populated with actual stores
        
        let helper = TenantImageHelper(dataManager: DataManager())
        return helper.getTenantImageForStep(step, from: stores)
    }
}

// MARK: - SwiftUI View for Tenant Image in Steps
struct TenantImageView: View {
    let step: EnhancedDirectionStep
    let stores: [Store]
    @State private var imageURL: URL? = nil
    
    var body: some View {
        Group {
            if let url = imageURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "building.2")
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Image(systemName: getDefaultIcon(for: step))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
            }
        }
        .onAppear {
            loadTenantImage()
        }
    }
    
    private func loadTenantImage() {
        let helper = TenantImageHelper(dataManager: DataManager())
        imageURL = helper.getTenantImageForStep(step, from: stores)
    }
    
    private func getDefaultIcon(for step: EnhancedDirectionStep) -> String {
        let description = step.description.lowercased()
        
        if description.contains("elevator") || description.contains("lift") {
            return "arrow.up.arrow.down.square"
        } else if description.contains("escalator") {
            return "arrow.up.right.square"
        } else if description.contains("stairs") {
            return "stairs"
        } else if description.contains("entrance") || description.contains("exit") {
            return "door.left.hand.open"
        } else if description.contains("restroom") || description.contains("toilet") {
            return "figure.walk.motion"
        } else {
            return "arrow.forward.circle"
        }
    }
}

// MARK: - Usage Example in Direction Step View
struct EnhancedDirectionStepCard: View {
    let step: EnhancedDirectionStep
    let stores: [Store]
    let index: Int
    let totalSteps: Int
    let isCurrentStep: Bool
    
    var body: some View {
        HStack {
            Image(systemName: step.icon)
                .foregroundColor(.white)
                .font(.system(size: 18, weight: .medium))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(step.description)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    Text("Step \(index + 1) of \(totalSteps)")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 12))
                    
                    Spacer()
                    
                    Text(PathfindingManager().formatDistance(step.distanceFromStart))
                        .foregroundColor(.white.opacity(0.9))
                        .font(.system(size: 11, weight: .medium))
                }
            }
            
            Spacer()
            
            // Enhanced tenant image view
            TenantImageView(step: step, stores: stores)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(isCurrentStep ? customBlueColor : customBlueColor.opacity(0.8))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: isCurrentStep ? 4 : 2)
        .scaleEffect(isCurrentStep ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isCurrentStep)
    }
}

let customBlueColor: Color = Color(uiColor: UIColor { traitCollection in
    if traitCollection.userInterfaceStyle == .dark {
        return UIColor(red: 64/255, green: 156/255, blue: 255/255, alpha: 1.0)
    } else {
        return UIColor(red: 0/255, green: 46/255, blue: 127/255, alpha: 1.0)
    }
})
