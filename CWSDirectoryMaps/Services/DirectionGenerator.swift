// DirectionGenerator.swift

import Foundation
import CoreGraphics

// MARK: - Direction Step Model
//struct DirectionStep: Identifiable {
//    let id = UUID()
//    let point: CGPoint
//    var instruction: String = ""
//    var iconName: String = "arrow.up"
//}


// MARK: - Directions Generator
class DirectionsGenerator {
    
    // MARK: - Private Helpers
    
    private func angle(from start: CGPoint, to end: CGPoint) -> CGFloat {
        return atan2(end.y - start.y, end.x - start.x)
    }
    
    private func key(for point: CGPoint) -> String {
        return "\(point.x),\(point.y)"
    }
    
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        return hypot(a.x - b.x, a.y - b.y)
    }
    
    // MARK: - Main Generation Function
    
    func generate(from pathWithLabels: [(point: CGPoint, label: String)], graph: Graph?, unifiedGraph: [String: GraphNode]) -> [DirectionStep] {
        guard pathWithLabels.count >= 2 else { return [] }
        
        let path = pathWithLabels.map { $0.point }
        
        // Group path segments by floor to handle multi-floor navigation
        var floorSegments: [(floor: Floor, pathData: [(point: CGPoint, label: String)])] = []
        var currentFloorPath: [(point: CGPoint, label: String)] = []
        var currentFloor = extractFloor(from: pathWithLabels[0].label)
        
        for pathItem in pathWithLabels {
            let itemFloor = extractFloor(from: pathItem.label)
            if itemFloor != currentFloor && !currentFloorPath.isEmpty {
                floorSegments.append((floor: currentFloor, pathData: currentFloorPath))
                currentFloorPath = [pathItem]
                currentFloor = itemFloor
            } else {
                currentFloorPath.append(pathItem)
            }
        }
        
        if !currentFloorPath.isEmpty {
            floorSegments.append((floor: currentFloor, pathData: currentFloorPath))
        }
        
        var allSteps: [DirectionStep] = []
        
        // Generate steps for each floor segment
        for (segmentIndex, segment) in floorSegments.enumerated() {
            let steps = generateStepsForFloor(
                pathData: segment.pathData,
                floor: segment.floor,
                unifiedGraph: unifiedGraph,
                isFirstSegment: segmentIndex == 0,
                isLastSegment: segmentIndex == floorSegments.count - 1
            )
            
            // Add floor transition steps if needed
            if segmentIndex > 0 {
                let previousFloor = floorSegments[segmentIndex - 1].floor
                let currentFloor = segment.floor
                
                let transitionStep = DirectionStep(
                    point: segment.pathData.first?.point ?? .zero,
                    icon: "arrow.up.down.circle",
                    description: "Change floors from \(floorDisplayName(for: previousFloor)) to \(floorDisplayName(for: currentFloor))",
                    shopImage: "floor-1",
                    isFloorChange: true,
                    fromFloor: previousFloor,
                    toFloor: currentFloor
                )
                allSteps.append(transitionStep)
            }
            
            allSteps.append(contentsOf: steps)
        }
        
        // Remove duplicate consecutive steps with same description
        allSteps = removeDuplicateSteps(allSteps)
        
        print("--- Generated \(allSteps.count) Enhanced Directional Steps ---")
        for step in allSteps {
            print("  - \(step.description)")
        }
        
        return allSteps
    }
    
    private func generateStepsForFloor(
        pathData: [(point: CGPoint, label: String)],
        floor: Floor,
        unifiedGraph: [String: GraphNode],
        isFirstSegment: Bool,
        isLastSegment: Bool
    ) -> [DirectionStep] {
        guard pathData.count >= 2 else { return [] }
        
        let path = pathData.map { $0.point }
        var steps: [DirectionStep] = []
        
        // Starting step only for first segment
        if isFirstSegment {
            let startPoint = path[0]
            let startLandmarks = findNearbyLandmarks(
                around: startPoint,
                unifiedGraph: unifiedGraph,
                currentFloor: floor
            )
            
            var startDescription = "Begin your journey"
            if !startLandmarks.isEmpty {
                startDescription = "Start from near \(startLandmarks.first!)"
            }
            
            steps.append(DirectionStep(
                point: startPoint,
                icon: "figure.walk",
                description: startDescription,
                shopImage: "floor-1"
            ))
        }
        
        // Generate intermediate steps with improved logic
        let significantPoints = findSignificantTurningPoints(pathData: pathData, unifiedGraph: unifiedGraph, floor: floor)
        
        for point in significantPoints {
            let landmarks = findNearbyLandmarks(
                around: point.point,
                unifiedGraph: unifiedGraph,
                currentFloor: floor,
                maxDistance: 80.0
            )
            
            let landmarkReference = landmarks.isEmpty ? "" : " near \(landmarks.first!)"
            let description = "Continue straight\(landmarkReference)"
            
            steps.append(DirectionStep(
                point: point.point,
                icon: "arrow.up",
                description: description,
                shopImage: "floor-1"
            ))
        }
        
        // Final destination step only for last segment
        if isLastSegment {
            let finalPoint = path.last!
            let finalLandmarks = findNearbyLandmarks(
                around: finalPoint,
                unifiedGraph: unifiedGraph,
                currentFloor: floor,
                maxDistance: 50.0
            )
            
            var finalDescription = "You have arrived at your destination"
            if !finalLandmarks.isEmpty {
                finalDescription = "Arrive at your destination near \(finalLandmarks.first!)"
            }
            
            steps.append(DirectionStep(
                point: finalPoint,
                icon: "mappin.circle.fill",
                description: finalDescription,
                shopImage: "floor-1"
            ))
        }
        
        return steps
    }
    
    private func findSignificantTurningPoints(
        pathData: [(point: CGPoint, label: String)],
        unifiedGraph: [String: GraphNode],
        floor: Floor
    ) -> [(point: CGPoint, label: String)] {
        guard pathData.count > 2 else { return [] }
        
        var significantPoints: [(point: CGPoint, label: String)] = []
        let minDistanceBetweenPoints: CGFloat = 100.0 // Minimum distance to avoid redundant steps
        
        for i in 1..<(pathData.count - 1) {
            let currentPoint = pathData[i]
            let prevPoint = pathData[i - 1]
            let nextPoint = pathData[i + 1]
            
            // Check if this is a significant turning point
            let angle1 = angle(from: prevPoint.point, to: currentPoint.point)
            let angle2 = angle(from: currentPoint.point, to: nextPoint.point)
            var angleDiff = abs((angle2 - angle1) * 180 / .pi)
            
            if angleDiff > 180 { angleDiff = 360 - angleDiff }
            
            // Only add if it's a significant turn (> 45 degrees) and far enough from last point
            if angleDiff > 45 {
                if significantPoints.isEmpty ||
                    distance(currentPoint.point, significantPoints.last!.point) > minDistanceBetweenPoints {
                    significantPoints.append(currentPoint)
                }
            }
        }
        
        return significantPoints
    }
    
    private func removeDuplicateSteps(_ steps: [DirectionStep]) -> [DirectionStep] {
        var uniqueSteps: [DirectionStep] = []
        var lastDescription = ""
        
        for step in steps {
            if step.description != lastDescription {
                uniqueSteps.append(step)
                lastDescription = step.description
            }
        }
        
        return uniqueSteps
    }
    
    private func floorDisplayName(for floor: Floor) -> String {
        switch floor {
        case .ground: return "Ground Floor"
        case .lowerGround: return "Lower Ground Floor"
        case .first: return "1st Floor"
        case .second: return "2nd Floor"
        case .third: return "3rd Floor"
        case .fourth: return "4th Floor"
        }
    }
    
    /// Find nearby landmarks/stores around a given point
    private func findNearbyLandmarks(
        around point: CGPoint,
        unifiedGraph: [String: GraphNode],
        currentFloor: Floor,
        maxDistance: CGFloat = 100.0
    ) -> [String] {
        var landmarks: [String] = []
        
        // Find store/landmark nodes near this point
        for (label, node) in unifiedGraph {
            guard node.floor == currentFloor else { continue }
            
            let nodePoint = CGPoint(x: node.x, y: node.y)
            let dist = distance(point, nodePoint)
            
            if dist <= maxDistance {
                // Look for store/landmark indicators
                if node.type == "ellipse-point" || node.type == "circle-point" || node.type == "rect-corner" {
                    if let parentLabel = node.parentLabel {
                        let cleanName = formatLandmarkName(parentLabel)
                        if !cleanName.isEmpty && !landmarks.contains(cleanName) {
                            landmarks.append(cleanName)
                        }
                    }
                }
            }
        }
        
        return landmarks.sorted()
    }
    
    /// Format landmark name to be more readable
    private func formatLandmarkName(_ rawName: String) -> String {
        // Remove prefixes and clean up the name
        var cleanName = rawName
            .replacingOccurrences(of: "ground_path_", with: "")
            .replacingOccurrences(of: "lowerground_path_", with: "")
            .replacingOccurrences(of: "1st_path_", with: "")
            .replacingOccurrences(of: "2nd_path_", with: "")
            .replacingOccurrences(of: "3rd_path_", with: "")
            .replacingOccurrences(of: "4th_path_", with: "")
        
        // Remove technical suffixes
        if cleanName.contains("storepath") {
            return "" // Skip technical path names
        }
        
        // Clean up underscores and format
        cleanName = cleanName.replacingOccurrences(of: "_", with: " ")
        
        // Capitalize words
        let words = cleanName.split(separator: " ")
        let capitalizedWords = words.map { word in
            String(word.prefix(1).uppercased() + word.dropFirst())
        }
        
        return capitalizedWords.joined(separator: " ")
    }
    
    /// Extract floor from unified graph label
    private func extractFloor(from label: String) -> Floor {
        if label.hasPrefix("ground_") { return .ground }
        if label.hasPrefix("lowerground_") { return .lowerGround }
        if label.hasPrefix("1st_") { return .first }
        if label.hasPrefix("2nd_") { return .second }
        if label.hasPrefix("3rd_") { return .third }
        if label.hasPrefix("4th_") { return .fourth }
        return .ground // default
    }
    
    /// Snaps `nextPoint` if it's very close to `currPoint`, then uses a counterpart point if available
    private func correctedAngle(prev: CGPoint, curr: CGPoint, pathNodes: [Node], index: Int) -> (CGFloat, CGPoint) {
        let currPoint = curr
        var nextPoint = CGPoint(x: pathNodes[index+1].x, y: pathNodes[index+1].y)
        
        // Snap tolerance (adjustable)
        if distance(currPoint, nextPoint) < 5.5 {
            // If next point is basically the same, skip ahead
            if index + 2 < pathNodes.count {
                nextPoint = CGPoint(x: pathNodes[index+2].x, y: pathNodes[index+2].y)
            }
        }
        
        let angle1 = angle(from: prev, to: currPoint)
        let angle2 = angle(from: currPoint, to: nextPoint)
        var angleDiff = (angle2 - angle1) * 180 / .pi
        
        // Normalize to [-180, 180]
        if angleDiff > 180 { angleDiff -= 360 }
        if angleDiff < -180 { angleDiff += 360 }
        
        // Treat ~180° as straight
        if abs(abs(angleDiff) - 180) < 15 {
            angleDiff = 0
        }
        
        // Suppress fake U-turns if still progressing forward
        let distPrevCurr = distance(prev, currPoint)
        let distPrevNext = distance(prev, nextPoint)
        if abs(angleDiff) > 150 && distPrevNext > distPrevCurr {
            angleDiff = 0
        }
        
        return (angleDiff, nextPoint)
    }
}
