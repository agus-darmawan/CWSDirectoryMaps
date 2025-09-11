// DirectionGenerator.swift

import Foundation
import CoreGraphics

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
    
    func generate(
        from pathWithLabels: [(point: CGPoint, label: String)],
        graph: Graph?,
        unifiedGraph: [String: GraphNode]
    ) -> [DirectionStep] {
        guard pathWithLabels.count >= 2 else { return [] }
        
        let path = pathWithLabels.map { $0.point }
        
        // Group path segments by floor
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
        
        // Generate steps
        var allSteps: [DirectionStep] = []
        
        for (segmentIndex, segment) in floorSegments.enumerated() {
            let steps = generateStepsForFloor(
                pathData: segment.pathData,
                floor: segment.floor,
                unifiedGraph: unifiedGraph
            )
            
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
        
        // Remove duplicate consecutive steps
        allSteps = removeDuplicateSteps(allSteps)
        
        // Handle escalator/lift replacement
        var i = 0
        while i < allSteps.count {
            if allSteps[i].description.localizedCaseInsensitiveContains("Continue to") {
                if i >= 2 {
                    let prevStep = allSteps[i - 2]
                    var directionWord = "straight"
                    if prevStep.description.localizedCaseInsensitiveContains("left") {
                        directionWord = "left"
                    } else if prevStep.description.localizedCaseInsensitiveContains("right") {
                        directionWord = "right"
                    }
                    
                    allSteps[i].description = "Take the escalator/lift to your \(directionWord)"
                    allSteps[i+1].description.replace("store", with: "escalator/lift")
                    
                    // Remove two steps before
                    allSteps.remove(at: i - 1)
                    allSteps.remove(at: i - 2)
                    i = max(i - 2, 0)
                } else {
                    i += 1
                }
            } else {
                i += 1
            }
        }
        
        print("--- Generated \(allSteps.count) Enhanced Directional Steps ---")
        for step in allSteps {
            print("  - \(step.description)")
        }
        
        return allSteps
    }
    
    // MARK: - Step Generation per Floor
    
    private func generateStepsForFloor(
        pathData: [(point: CGPoint, label: String)],
        floor: Floor,
        unifiedGraph: [String: GraphNode]
    ) -> [DirectionStep] {
        guard pathData.count >= 2 else { return [] }
        
        var steps: [DirectionStep] = []
        
        var pathNodes = pathData.compactMap { unifiedGraph[$0.label] }
            .filter { !$0.label.contains("_split") }
        
        // Variables grouped up front
        var lastParentLabel = pathNodes.first?.parentLabel
        var usedLandmarks: [String] = []
        var storepathCount = 0
        var angleAccumulator: CGFloat = 0
        var i = 1
        
        // --- Helper functions ---
        
        func findMinDistance(
            between nodesA: [GraphNode],
            and nodesB: [GraphNode]
        ) -> (dist: CGFloat, pair: (GraphNode, GraphNode))? {
            var minDistance: CGFloat = .infinity
            var minPair: (GraphNode, GraphNode)?
            
            for a in nodesA {
                for b in nodesB {
                    if a.id == b.id { continue }
                    let d = distance(CGPoint(x: a.x, y: a.y), CGPoint(x: b.x, y: b.y))
                    if d < minDistance {
                        minDistance = d
                        minPair = (a, b)
                    }
                }
            }
            return minPair != nil ? (minDistance, minPair!) : nil
        }
        
        func endpoints(for parentLabel: String?) -> [GraphNode] {
            guard let parentLabel = parentLabel else { return [] }
            return unifiedGraph.values.filter {
                $0.parentLabel == parentLabel || $0.label.hasPrefix(parentLabel + "_point_")
            }
        }
        
        func findClosestLandmark(around point: CGPoint) -> String? {
            let nearbyStores = findNearbyLandmarks(
                around: point,
                unifiedGraph: unifiedGraph,
                currentFloor: floor,
                maxDistance: 120
            )
            let filteredStores = nearbyStores.filter { !$0.lowercased().hasPrefix("atrium") }
            
            if let closestStore = filteredStores.min(by: { lhs, rhs in
                guard let lhsNode = unifiedGraph[lhs],
                      let rhsNode = unifiedGraph[rhs] else { return false }
                let lhsDist = hypot(lhsNode.x - point.x, lhsNode.y - point.y)
                let rhsDist = hypot(rhsNode.x - point.x, rhsNode.y - point.y)
                return lhsDist < rhsDist
            }) {
                return closestStore
            }
            return nil
        }
        
        // --- Main processing loop ---
        
        while i < pathNodes.count - 1 {
            var shouldSkipIncrement = false
            
            // Intersection detection
            if i + 2 < pathNodes.count {
                let nodeA = pathNodes[i]
                let nodeB = pathNodes[i+1]
                let nodeC = pathNodes[i+2]
                
                let nodesAAll = endpoints(for: nodeA.parentLabel)
                let nodesBAll = endpoints(for: nodeB.parentLabel)
                let nodesCAll = endpoints(for: nodeC.parentLabel)
                
                if let ab = findMinDistance(between: nodesAAll, and: nodesBAll),
                   let bc = findMinDistance(between: nodesBAll, and: nodesCAll),
                   let ac = findMinDistance(between: nodesAAll, and: nodesCAll),
                   (ab.dist + bc.dist + ac.dist) < 8 {
                    
                    pathNodes.remove(at: i + 1)
                    shouldSkipIncrement = true
                }
            }
            
            // Path processing
            guard let currentParentLabel = pathNodes[i].parentLabel else {
                if !shouldSkipIncrement { i += 1 }
                continue
            }
            
            if currentParentLabel != lastParentLabel {
                let nextNodeOnPath = pathNodes[i+1]
                var p1: CGPoint?, p2: CGPoint?, p3: CGPoint?
                
                // Junction point calculation
                if let lastLabel = lastParentLabel {
                    let prevNodes = unifiedGraph.values.filter { $0.parentLabel == lastLabel }
                    let nextNodes = unifiedGraph.values.filter { $0.parentLabel == currentParentLabel }

                    // --- START: NEW & IMPROVED LOGIC ---
                    var minDistance: CGFloat = .infinity
                    var junctionPair: (prev: GraphNode, next: GraphNode)? = nil

                    // 1. Find the true junction by finding the closest pair of nodes between the two segments.
                    for pNode in prevNodes {
                        for nNode in nextNodes {
                            let d = distance(CGPoint(x: pNode.x, y: pNode.y), CGPoint(x: nNode.x, y: nNode.y))
                            if d < minDistance {
                                minDistance = d
                                junctionPair = (pNode, nNode)
                            }
                        }
                    }

                    // 2. Use the junction pair to correctly identify the start, junction, and end points.
                    if let pair = junctionPair,
                       let startNode = prevNodes.first(where: { $0.id != pair.prev.id }),
                       let endNode = nextNodes.first(where: { $0.id != pair.next.id }) {
                        
                        // 3. Assign points and normalize Y-coordinates to prevent data issues.
                        p1 = CGPoint(x: startNode.x, y: abs(startNode.y))
                        p2 = CGPoint(x: pair.prev.x, y: abs(pair.prev.y)) // Use the junction point from the previous segment
                        p3 = CGPoint(x: endNode.x, y: abs(endNode.y))
                    }
                    // --- END: NEW & IMPROVED LOGIC ---
                }
                // Generate step if valid
                if let point1 = p1, let point2 = p2, let point3 = p3 {
                    let angle1 = angle(from: point1, to: point2)
                    let angle2 = angle(from: point2, to: point3)
                    
                    var angleDifference = (angle2 - angle1) * 180 / .pi
                    if angleDifference > 180 { angleDifference -= 360 }
                    if angleDifference < -180 { angleDifference += 360 }
                    
                    angleAccumulator += abs(angleDifference)
                    
                    let pathName = currentParentLabel.replacingOccurrences(of: "_", with: " ").capitalized
                    let isFirstStep = (i == 2)
                    let isLastStep = (i == pathNodes.count - 2)
                    
                    var iconName = "arrow.up"
                    var description = ""
                    
                    // --- NEW, UPDATED LOGIC ---
                    // --- START: NEW & IMPROVED LOGIC ---

                    // Get the final destination's unique identifier (its label or parentLabel).
                    let destinationIdentifier = pathNodes.last?.parentLabel ?? pathNodes.last?.label

                    // The next node in the path sequence.
                    let nextNodeOnPath = pathNodes[i+1]

                    // Determine if we are on the final approach.
                    let isNextNodeTheDestination = (nextNodeOnPath.parentLabel ?? nextNodeOnPath.label) == destinationIdentifier
                    let isApproachingOnStorepath = currentParentLabel.contains("storepath")
                    let isApproachingDestination = isNextNodeTheDestination || isApproachingOnStorepath


                    if isApproachingDestination || isLastStep {
                        // This is the final turn towards the destination.
                        if let destinationNode = pathNodes.last {
                            let destinationLabel = destinationNode.parentLabel ?? destinationNode.label
                            let destinationName = formatLandmarkName(destinationLabel)
                            
                            var directionPrefix = ""
                            
                            // This logic correctly determines the final turn's direction
                            if angleDifference >= 45 {
                                directionPrefix = "On your right should be"
                                iconName = "arrow.turn.up.right"
                            } else if angleDifference >= 30 {
                                directionPrefix = "Slightly to your right should be"
                                iconName = "arrow.up.right"
                            } else if angleDifference <= -45 {
                                directionPrefix = "On your left should be"
                                iconName = "arrow.turn.up.left"
                            } else if angleDifference <= -30 {
                                directionPrefix = "Slightly to your left should be"
                                iconName = "arrow.up.left"
                            } else {
                                directionPrefix = "Ahead should be"
                                iconName = "arrow.up"
                            }
                            
                            // Combine them into the final description
                            description = "\(directionPrefix) \(destinationName)"
                        }
                    } else if isFirstStep {
                        // Logic for the first step remains the same.
                        if angleDifference >= 45 {
                            description = "Exit from the store and turn right"
                            iconName = "arrow.turn.up.right"
                        } else if angleDifference >= 30 {
                            description = "Exit from the store and bear right"
                            iconName = "arrow.up.right"
                        } else if angleDifference <= -45 {
                            description = "Exit from the store and turn left"
                            iconName = "arrow.turn.up.left"
                        } else if angleDifference <= -30 {
                            description = "Exit from the store and bear left"
                            iconName = "arrow.up.left"
                        } else {
                            description = "Exit from the store and continue straight"
                            iconName = "arrow.up"
                        }
                    } else {
                        // Logic for all intermediate steps remains the same.
                        if angleDifference >= 45 {
                            description = "Turn right"
                            iconName = "arrow.turn.up.right"
                        } else if angleDifference >= 30 {
                            description = "Bear right"
                            iconName = "arrow.up.right"
                        } else if angleDifference <= -45 {
                            description = "Turn left"
                            iconName = "arrow.turn.up.left"
                        } else if angleDifference <= -30 {
                            description = "Bear left"
                            iconName = "arrow.up.left"
                        } else {
                            description = "Continue straight"
                            iconName = "arrow.up"
                        }
                    }
                    // --- END: NEW & IMPROVED LOGIC ---

                    // Landmarks
                    if !isFirstStep && !isApproachingDestination && !isLastStep {
                        if angleAccumulator >= 10 {
                            if let landmark = findClosestLandmark(around: point2), !usedLandmarks.contains(landmark) {
                                description += " until you pass \(landmark)"
                                usedLandmarks.append(landmark)
                            }
                            angleAccumulator = 0
                        }
                    }
                    
                    if description.contains("Exit from") ||
                       description.contains("until you pass") ||
                       description.contains(" should ") {

                        steps.append(DirectionStep(
                            point: point2,
                            icon: iconName,
                            description: description,
                            shopImage: floor.imageName
                        ))
                    }
                }
                
                lastParentLabel = currentParentLabel
            }

            if !shouldSkipIncrement {
                i += 1
            }
        }
        
        return steps
    }
    
    // MARK: - Utils
    
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
    
    private func findNearbyLandmarks(
        around point: CGPoint,
        unifiedGraph: [String: GraphNode],
        currentFloor: Floor,
        maxDistance: CGFloat = 50.0
    ) -> [String] {
        var landmarks: [String] = []
        
        for (label, node) in unifiedGraph {
            guard node.floor == currentFloor else { continue }
            
            let nodePoint = CGPoint(x: node.x, y: node.y)
            let dist = distance(point, nodePoint)
            
            if dist <= maxDistance {
                if node.type == "ellipse-point" || node.type == "circle-point" {
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
    
    private func formatLandmarkName(_ rawName: String) -> String {
        var cleanName = rawName
            .replacingOccurrences(of: "ground_path_", with: "")
            .replacingOccurrences(of: "lowerground_path_", with: "")
            .replacingOccurrences(of: "1st_path_", with: "")
            .replacingOccurrences(of: "2nd_path_", with: "")
            .replacingOccurrences(of: "3rd_path_", with: "")
            .replacingOccurrences(of: "4th_path_", with: "")
        
        if cleanName.contains("storepath") {
            return ""
        }
        
        cleanName = cleanName.replacingOccurrences(of: "_", with: " ")
        
        let words = cleanName.split(separator: " ")
        let capitalizedWords = words.map { word in
            String(word.prefix(1).uppercased() + word.dropFirst())
        }
        
        return capitalizedWords.joined(separator: " ")
    }
    
    private func extractFloor(from label: String) -> Floor {
        if label.hasPrefix("ground_") { return .ground }
        if label.hasPrefix("lowerground_") { return .lowerGround }
        if label.hasPrefix("1st_") { return .first }
        if label.hasPrefix("2nd_") { return .second }
        if label.hasPrefix("3rd_") { return .third }
        if label.hasPrefix("4th_") { return .fourth }
        return .ground
    }
}
