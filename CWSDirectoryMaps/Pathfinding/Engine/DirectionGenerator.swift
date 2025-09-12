//
// DirectionGenerator.swift
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 02/09/25.
//

import Foundation
import CoreGraphics

class DirectionsGenerator {
    
    // MARK: - Public Interface
    
    func generate(
        from pathWithLabels: [(point: CGPoint, label: String)],
        graph: Graph?,
        unifiedGraph: [String: GraphNode]
    ) -> [DirectionStep] {
        guard pathWithLabels.count >= 2 else { return [] }
        
        let floorSegments = groupPathByFloor(pathWithLabels)
        var allSteps: [DirectionStep] = []
        
        for (segmentIndex, segment) in floorSegments.enumerated() {
            let entryPointNoun = determineEntryPointNoun(for: segment, isFirst: segmentIndex == 0)
            
            let steps = generateStepsForFloor(
                pathData: segment.pathData,
                floor: segment.floor,
                unifiedGraph: unifiedGraph,
                isFirstSegment: segmentIndex == 0,
                entryPointNoun: entryPointNoun
            )
            
            // Add floor transition step if needed
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
        
        allSteps = removeDuplicateSteps(allSteps)
        
        print("--- Generated \(allSteps.count) Enhanced Directional Steps ---")
        for step in allSteps {
            print("  - \(step.description)")
        }
        
        return allSteps
    }
    
    // MARK: - Floor Segmentation
    
    private func groupPathByFloor(_ pathWithLabels: [(point: CGPoint, label: String)]) -> [(floor: Floor, pathData: [(point: CGPoint, label: String)])] {
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
        
        return floorSegments
    }
    
    private func determineEntryPointNoun(for segment: (floor: Floor, pathData: [(point: CGPoint, label: String)]), isFirst: Bool) -> String {
        if isFirst {
            return "the store"
        }
        
        if let firstNodeLabel = segment.pathData.first?.label.lowercased() {
            if firstNodeLabel.contains("escalator") {
                return "the Escalator"
            } else if firstNodeLabel.contains("lift") {
                return "the Elevator"
            }
        }
        
        return "the store"
    }
    
    // MARK: - Step Generation
    
    private func generateStepsForFloor(
        pathData: [(point: CGPoint, label: String)],
        floor: Floor,
        unifiedGraph: [String: GraphNode],
        isFirstSegment: Bool,
        entryPointNoun: String
    ) -> [DirectionStep] {
        guard pathData.count >= 2 else { return [] }
        
        var steps: [DirectionStep] = []
        var pathNodes = pathData.compactMap { unifiedGraph[$0.label] }
            .filter { !$0.label.contains("_split") }
        
        var lastParentLabel = pathNodes.first?.parentLabel
        var usedLandmarks: [String] = []
        var i = 1
        
        while i < pathNodes.count - 1 {
            var shouldSkipIncrement = false
            
            // Remove intersection nodes to simplify path
            if i + 2 < pathNodes.count {
                let nodeA = pathNodes[i]
                let nodeB = pathNodes[i+1]
                let nodeC = pathNodes[i+2]
                
                let nodesAAll = endpoints(for: nodeA.parentLabel, in: unifiedGraph)
                let nodesBAll = endpoints(for: nodeB.parentLabel, in: unifiedGraph)
                let nodesCAll = endpoints(for: nodeC.parentLabel, in: unifiedGraph)
                
                if let ab = findMinDistance(between: nodesAAll, and: nodesBAll),
                   let bc = findMinDistance(between: nodesBAll, and: nodesCAll),
                   let ac = findMinDistance(between: nodesAAll, and: nodesCAll),
                   (ab.dist + bc.dist + ac.dist) < 8 {
                    
                    pathNodes.remove(at: i + 1)
                    shouldSkipIncrement = true
                }
            }
            
            guard let currentParentLabel = pathNodes[i].parentLabel else {
                if !shouldSkipIncrement { i += 1 }
                continue
            }
            
            // Generate step when transitioning between different path segments
            if currentParentLabel != lastParentLabel {
                let newSteps = generateTransitionStep(
                    from: lastParentLabel,
                    to: currentParentLabel,
                    pathNodes: pathNodes,
                    index: i,
                    unifiedGraph: unifiedGraph,
                    floor: floor,
                    isFirstSegment: isFirstSegment,
                    entryPointNoun: entryPointNoun,
                    usedLandmarks: &usedLandmarks
                )
                steps.append(contentsOf: newSteps)
                
                lastParentLabel = currentParentLabel
            }
            
            if !shouldSkipIncrement {
                i += 1
            }
        }
        
        return steps
    }

    private func generateTransitionStep(
        from previousParentLabel: String?,
        to currentParentLabel: String,
        pathNodes: [GraphNode],
        index: Int,
        unifiedGraph: [String: GraphNode],
        floor: Floor,
        isFirstSegment: Bool,
        entryPointNoun: String,
        usedLandmarks: inout [String]
    ) -> [DirectionStep] { // ✅ RETURN TYPE CHANGED to [DirectionStep]

        let nextNodeOnPath = pathNodes[index+1]
        
        guard let (p1, p2, p3) = calculateJunctionPoints(
            previousParentLabel: previousParentLabel,
            currentParentLabel: currentParentLabel,
            unifiedGraph: unifiedGraph
        ) else {
            return [] // ✅ RETURN EMPTY ARRAY instead of nil
        }
        
        let angle1 = angle(from: p1, to: p2)
        let angle2 = angle(from: p2, to: p3)
        
        var angleDifference = (angle2 - angle1) * 180 / .pi
        if angleDifference > 180 { angleDifference -= 360 }
        if angleDifference < -180 { angleDifference += 360 }
        
        let isFirstStepInSegment = (index == 1) // Adjusted to be more accurate
        let isLastStep = (index >= pathNodes.count - 2)
        
        let destinationIdentifier = pathNodes.last?.parentLabel ?? pathNodes.last?.label
        let isNextNodeTheDestination = (nextNodeOnPath.parentLabel ?? nextNodeOnPath.label) == destinationIdentifier
        let isApproachingOnStorepath = currentParentLabel.contains("storepath")
        let isApproachingDestination = isNextNodeTheDestination || isApproachingOnStorepath
        
        if isFirstStepInSegment {
            let (description, iconName) = generateExitInstruction(angleDifference: angleDifference, entryPointNoun: entryPointNoun)
            // ✅ RETURN AS ARRAY
            return [DirectionStep(point: p2, icon: iconName, description: description, shopImage: floor.imageName)]
            
        } else if isApproachingDestination || isLastStep {
            if let destinationName = destinationIdentifier.map(formatLandmarkName),
               !usedLandmarks.contains(destinationName) {
                let (description, iconName) = generateDestinationInstruction(angleDifference: angleDifference, destinationName: destinationName)
                usedLandmarks.append(destinationName)
                // ✅ RETURN AS ARRAY
                return [DirectionStep(point: p2, icon: iconName, description: description, shopImage: floor.imageName)]
            } else {
                return [] // ✅ RETURN EMPTY ARRAY instead of nil
            }
            
        } else {
            // This now returns [DirectionStep] directly
            return generateIntermediateStep(
                angleDifference: angleDifference,
                p2: p2,
                p3: p3,
                unifiedGraph: unifiedGraph,
                floor: floor,
                usedLandmarks: &usedLandmarks
            )
        }
    }
    private func generateExitInstruction(angleDifference: CGFloat, entryPointNoun: String) -> (String, String) {
        if angleDifference >= 45 {
            return ("Exit from \(entryPointNoun) and turn right", "arrow.turn.up.right")
        } else if angleDifference >= 30 {
            return ("Exit from \(entryPointNoun) and bear right", "arrow.up.right")
        } else if angleDifference <= -45 {
            return ("Exit from \(entryPointNoun) and turn left", "arrow.turn.up.left")
        } else if angleDifference <= -30 {
            return ("Exit from \(entryPointNoun) and bear left", "arrow.up.left")
        } else {
            return ("Exit from \(entryPointNoun) and continue straight", "arrow.up")
        }
    }
    
    private func generateDestinationInstruction(angleDifference: CGFloat, destinationName: String) -> (String, String) {
        if angleDifference >= 45 {
            return ("On your right should be \(destinationName)", "arrow.turn.up.right")
        } else if angleDifference >= 30 {
            return ("Slightly to your right should be \(destinationName)", "arrow.up.right")
        } else if angleDifference <= -45 {
            return ("On your left should be \(destinationName)", "arrow.turn.up.left")
        } else if angleDifference <= -30 {
            return ("Slightly to your left should be \(destinationName)", "arrow.up.left")
        } else {
            return ("Ahead should be \(destinationName)", "arrow.up")
        }
    }
    
    // ✅ PASTE this new function in its place
    private func generateIntermediateStep(
        angleDifference: CGFloat,
        p2: CGPoint,
        p3: CGPoint,
        unifiedGraph: [String: GraphNode],
        floor: Floor,
        usedLandmarks: inout [String]
    ) -> [DirectionStep] {
        
        var newSteps: [DirectionStep] = []
        let turnThreshold: CGFloat = 35.0
        let didTurn = abs(angleDifference) >= turnThreshold

        if didTurn {
            // --- Case 1: A turn was detected ---
            // First, create the "Turn" instruction.
            let turnDescription = angleDifference > 0 ? "Turn right" : "Turn left"
            let turnIcon = angleDifference > 0 ? "arrow.turn.up.right" : "arrow.turn.up.left"
            newSteps.append(DirectionStep(point: p2, icon: turnIcon, description: turnDescription, shopImage: floor.imageName))
            
            // Second, automatically add a "Continue straight" to confirm the new direction.
            newSteps.append(DirectionStep(point: p2, icon: "arrow.up", description: "Continue straight", shopImage: floor.imageName))

        } else {
            // --- Case 2: No turn was detected ---
            // Generate a single "Continue" instruction, enhanced with a landmark if possible.
            let midPointX = (p2.x + p3.x) / 2
            let midPointY = (p2.y + p3.y) / 2
            let searchPoint = CGPoint(x: midPointX, y: midPointY)
            
            var description = ""
            if let landmarkNode = findClosestLandmark(around: searchPoint, unifiedGraph: unifiedGraph, floor: floor),
               let landmarkName = landmarkNode.parentLabel.map(formatLandmarkName),
               !usedLandmarks.contains(landmarkName) {
                
                let landmarkPoint = CGPoint(x: landmarkNode.x, y: landmarkNode.y)
                let distanceToTurn = distance(landmarkPoint, p3)
                let proximityThreshold: CGFloat = 40.0
                
                description = distanceToTurn < proximityThreshold
                    ? "Continue towards \(landmarkName)"
                    : "Continue straight until you pass \(landmarkName)"
                usedLandmarks.append(landmarkName)
            } else {
                description = "Continue straight"
            }
            newSteps.append(DirectionStep(point: p2, icon: "arrow.up", description: description, shopImage: floor.imageName))
        }
        
        return newSteps
    }
    
    // MARK: - Geometric Calculations
    
    private func calculateJunctionPoints(
        previousParentLabel: String?,
        currentParentLabel: String,
        unifiedGraph: [String: GraphNode]
    ) -> (CGPoint, CGPoint, CGPoint)? {
        guard let lastLabel = previousParentLabel else { return nil }
        
        let prevNodes = unifiedGraph.values.filter { $0.parentLabel == lastLabel }
        let nextNodes = unifiedGraph.values.filter { $0.parentLabel == currentParentLabel }
        
        var minDistance: CGFloat = .infinity
        var junctionPair: (prev: GraphNode, next: GraphNode)? = nil
        
        for pNode in prevNodes {
            for nNode in nextNodes {
                let d = distance(CGPoint(x: pNode.x, y: pNode.y), CGPoint(x: nNode.x, y: nNode.y))
                if d < minDistance {
                    minDistance = d
                    junctionPair = (pNode, nNode)
                }
            }
        }
        
        guard let pair = junctionPair,
              let startNode = prevNodes.first(where: { $0.id != pair.prev.id }),
              let endNode = nextNodes.first(where: { $0.id != pair.next.id }) else {
            return nil
        }
        
        let p1 = CGPoint(x: startNode.x, y: abs(startNode.y))
        let p2 = CGPoint(x: pair.prev.x, y: abs(pair.prev.y))
        let p3 = CGPoint(x: endNode.x, y: abs(endNode.y))
        
        return (p1, p2, p3)
    }
    
    private func findMinDistance(
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
    
    private func endpoints(for parentLabel: String?, in unifiedGraph: [String: GraphNode]) -> [GraphNode] {
        guard let parentLabel = parentLabel else { return [] }
        return unifiedGraph.values.filter {
            $0.parentLabel == parentLabel || $0.label.hasPrefix(parentLabel + "_point_")
        }
    }
    
    // MARK: - Landmark Finding
    
    private func findClosestLandmark(
        around point: CGPoint,
        unifiedGraph: [String: GraphNode],
        floor: Floor
    ) -> GraphNode? {
        let nearbyNodes = findNearbyLandmarks(
            around: point,
            unifiedGraph: unifiedGraph,
            currentFloor: floor,
            maxDistance: 80.0
        )
        
        let closestNode = nearbyNodes.min { lhsNode, rhsNode in
            let lhsDist = distance(CGPoint(x: lhsNode.x, y: lhsNode.y), point)
            let rhsDist = distance(CGPoint(x: rhsNode.x, y: rhsNode.y), point)
            return lhsDist < rhsDist
        }
        
        // Filter out atrium landmarks
        if let closestNode = closestNode,
           let parentLabel = closestNode.parentLabel,
           parentLabel.lowercased().contains("atrium") {
            return nil
        }
        
        return closestNode
    }
    
    private func findNearbyLandmarks(
        around point: CGPoint,
        unifiedGraph: [String: GraphNode],
        currentFloor: Floor,
        maxDistance: CGFloat = 80.0
    ) -> [GraphNode] {
        let storeNodes = unifiedGraph.values.filter {
            $0.floor == currentFloor && ($0.type == "ellipse-point" || $0.type == "circle-point")
        }
        
        var landmarkNodes: [GraphNode] = []
        
        for node in storeNodes {
            let nodePoint = CGPoint(x: node.x, y: node.y)
            if distance(point, nodePoint) <= maxDistance {
                // Avoid duplicate landmarks from the same store
                if let parentLabel = node.parentLabel,
                   !landmarkNodes.contains(where: { $0.parentLabel == parentLabel }) {
                    landmarkNodes.append(node)
                }
            }
        }
        
        return landmarkNodes
    }
    
    // MARK: - Utility Functions
    
    private func angle(from start: CGPoint, to end: CGPoint) -> CGFloat {
        return atan2(end.y - start.y, end.x - start.x)
    }
    
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        return hypot(a.x - b.x, a.y - b.y)
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
    
    // MARK: - String Formatting
    
    private func formatLandmarkName(_ rawName: String) -> String {
        let lowercasedName = rawName.lowercased()
        
        if lowercasedName.contains("escalator") {
            return "the Escalator"
        }
        if lowercasedName.contains("lift") {
            return "the Elevator"
        }
        
        var cleanName = rawName
        for floor in Floor.allCases {
            cleanName = cleanName.replacingOccurrences(of: floor.pathPrefix + "path_", with: "")
        }
        
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
    
    private func extractFloor(from label: String) -> Floor {
        for floor in Floor.allCases {
            if label.hasPrefix(floor.pathPrefix) {
                return floor
            }
        }
        return .ground // Default fallback
    }
}
