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
                if let step = generateTransitionStep(
                    from: lastParentLabel,
                    to: currentParentLabel,
                    pathNodes: pathNodes,
                    index: i,
                    unifiedGraph: unifiedGraph,
                    floor: floor,
                    isFirstSegment: isFirstSegment,
                    entryPointNoun: entryPointNoun,
                    usedLandmarks: &usedLandmarks
                ) {
                    steps.append(step)
                }
                
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
    ) -> DirectionStep? {
        let nextNodeOnPath = pathNodes[index+1]
        
        // Calculate junction points for angle determination
        guard let (p1, p2, p3) = calculateJunctionPoints(
            previousParentLabel: previousParentLabel,
            currentParentLabel: currentParentLabel,
            unifiedGraph: unifiedGraph
        ) else {
            return nil
        }
        
        let angle1 = angle(from: p1, to: p2)
        let angle2 = angle(from: p2, to: p3)
        
        var angleDifference = (angle2 - angle1) * 180 / .pi
        if angleDifference > 180 { angleDifference -= 360 }
        if angleDifference < -180 { angleDifference += 360 }
        
        let isFirstStepInSegment = (index == 2)
        let isLastStep = (index == pathNodes.count - 2)
        
        let destinationIdentifier = pathNodes.last?.parentLabel ?? pathNodes.last?.label
        let isNextNodeTheDestination = (nextNodeOnPath.parentLabel ?? nextNodeOnPath.label) == destinationIdentifier
        let isApproachingOnStorepath = currentParentLabel.contains("storepath")
        let isApproachingDestination = isNextNodeTheDestination || isApproachingOnStorepath
        
        var description = ""
        var iconName = "arrow.up"
        
        if isFirstStepInSegment {
            (description, iconName) = generateExitInstruction(angleDifference: angleDifference, entryPointNoun: entryPointNoun)
        } else if isApproachingDestination || isLastStep {
            if let destinationName = destinationIdentifier.map(formatLandmarkName),
               !usedLandmarks.contains(destinationName) {
                (description, iconName) = generateDestinationInstruction(angleDifference: angleDifference, destinationName: destinationName)
                usedLandmarks.append(destinationName)
            } else {
                return nil
            }
        } else {
            return generateIntermediateStep(
                angleDifference: angleDifference,
                p2: p2,
                p3: p3,
                unifiedGraph: unifiedGraph,
                floor: floor,
                usedLandmarks: &usedLandmarks
            )
        }
        
        return DirectionStep(point: p2, icon: iconName, description: description, shopImage: floor.imageName)
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
    
    private func generateIntermediateStep(
        angleDifference: CGFloat,
        p2: CGPoint,
        p3: CGPoint,
        unifiedGraph: [String: GraphNode],
        floor: Floor,
        usedLandmarks: inout [String]
    ) -> DirectionStep? {
        let midPointX = (p2.x + p3.x) / 2
        let midPointY = (p2.y + p3.y) / 2
        let searchPoint = CGPoint(x: midPointX, y: midPointY)
        
        if let landmarkNode = findClosestLandmark(around: searchPoint, unifiedGraph: unifiedGraph, floor: floor),
           let landmarkName = landmarkNode.parentLabel.map(formatLandmarkName),
           !usedLandmarks.contains(landmarkName) {
            
            let isFloorTransition = landmarkName.lowercased().contains("escalator") || landmarkName.lowercased().contains("elevator")
            var description = ""
            var iconName = "arrow.up"
            
            if isFloorTransition {
                (description, iconName) = generateDestinationInstruction(angleDifference: angleDifference, destinationName: landmarkName)
            } else {
                let landmarkPoint = CGPoint(x: landmarkNode.x, y: landmarkNode.y)
                let distanceToTurn = distance(landmarkPoint, p3)
                let proximityThreshold: CGFloat = 40.0
                
                description = distanceToTurn < proximityThreshold
                    ? "Continue towards \(landmarkName)"
                    : "Continue straight until you pass \(landmarkName)"
            }
            
            usedLandmarks.append(landmarkName)
            return DirectionStep(point: p2, icon: iconName, description: description, shopImage: floor.imageName)
            
        } else {
            // Generate turn instruction for sharp corners
            let turnThreshold = 40.0
            if abs(angleDifference) >= turnThreshold {
                let description = angleDifference > 0 ? "Turn right" : "Turn left"
                let iconName = angleDifference > 0 ? "arrow.turn.up.right" : "arrow.turn.up.left"
                return DirectionStep(point: p2, icon: iconName, description: description, shopImage: floor.imageName)
            } else {
                // Generic continue instruction for gradual turns
                return DirectionStep(point: p2, icon: "arrow.up", description: "Continue straight", shopImage: floor.imageName)
            }
        }
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
        if label.hasPrefix("ground_") { return .ground }
        if label.hasPrefix("lowerground_") { return .lowerGround }
        if label.hasPrefix("1st_") { return .first }
        if label.hasPrefix("2nd_") { return .second }
        if label.hasPrefix("3rd_") { return .third }
        if label.hasPrefix("4th_") { return .fourth }
        return .ground
    }
}
