// DirectionGenerator.swift

import Foundation
import CoreGraphics

// MARK: - Direction Step Model
struct DirectionStep: Identifiable {
    let id = UUID()
    let point: CGPoint
    var instruction: String = ""
    var iconName: String = "arrow.up"
}


// MARK: - Directions Generator
class DirectionsGenerator {
    
    // Calculates the angle between two points in radians.
    private func angle(from start: CGPoint, to end: CGPoint) -> CGFloat {
        return atan2(end.y - start.y, end.x - start.x)
    }

    // Creates a unique string key for a CGPoint to use in dictionaries.
    private func key(for point: CGPoint) -> String {
        return "\(point.x),\(point.y)"
    }

    // The main function to generate turn-by-turn directions using path semantics.
    func generate(from path: [CGPoint], graph: Graph?) -> [DirectionStep] {
        guard let fullGraph = graph, path.count >= 2 else { return [] }

        let coordToNodeMap = Dictionary(uniqueKeysWithValues: fullGraph.nodes.map { (key(for: CGPoint(x: $0.x, y: $0.y)), $0) })
        
        let pathNodes = path.compactMap { coordToNodeMap[key(for: $0)] }
        guard pathNodes.count >= 2 else { return [] }
        
        var steps: [DirectionStep] = []
        
        let startNode = pathNodes[0]
        if let startLabel = startNode.parentLabel ?? startNode.label {
            let formattedStartLabel = startLabel.replacingOccurrences(of: "_", with: " ").capitalized
            steps.append(DirectionStep(point: path[0], instruction: "Proceed to the exit of \(formattedStartLabel)"))
        } else {
            steps.append(DirectionStep(point: path[0], instruction: "Begin your journey."))
        }

        var lastParentLabel = startNode.parentLabel
        var isFirstTurnSkipped = false

        for i in 1..<(pathNodes.count - 1) {
            let currentNode = pathNodes[i]
            let nextNodeOnPath = pathNodes[i+1]

            guard let currentParentLabel = currentNode.parentLabel else { continue }

            if currentParentLabel != lastParentLabel {
                
                let currentPoint = CGPoint(x: currentNode.x, y: currentNode.y)
                var entryPoint = CGPoint.zero
                
                if let lastLabel = lastParentLabel {
                    let prevPathNodes = fullGraph.nodes.filter { $0.parentLabel == lastLabel }
                    if prevPathNodes.count == 2 {
                        if let entryNode = prevPathNodes.first(where: { $0.id != currentNode.id }) {
                             entryPoint = CGPoint(x: entryNode.x, y: entryNode.y)
                        } else {
                             entryPoint = CGPoint(x: pathNodes[i-1].x, y: pathNodes[i-1].y)
                        }
                    } else {
                        entryPoint = CGPoint(x: pathNodes[i-1].x, y: pathNodes[i-1].y)
                    }
                } else {
                    entryPoint = CGPoint(x: pathNodes[i-1].x, y: pathNodes[i-1].y)
                }

                let newPathNodes = fullGraph.nodes.filter { $0.parentLabel == currentParentLabel }
                guard newPathNodes.count == 2 else { continue }
                let farEndNode = (newPathNodes[0].id == nextNodeOnPath.id || newPathNodes[0].id == currentNode.id) ? newPathNodes[1] : newPathNodes[0]
                let lookAheadPoint = CGPoint(x: farEndNode.x, y: farEndNode.y)
                
                let angle1 = angle(from: entryPoint, to: currentPoint)
                let angle2 = angle(from: currentPoint, to: lookAheadPoint)

                var angleDifference = (angle2 - angle1) * 180 / .pi
                if angleDifference > 180 { angleDifference -= 360 }
                if angleDifference < -180 { angleDifference += 360 }

                // --- NEW DEBUGGING LINE ---
                print("-> Angle check at node \(currentNode.id) (\(lastParentLabel ?? "Start") -> \(currentParentLabel)): \(String(format: "%.2f", angleDifference)) degrees")

                var instructionText = ""
                var iconName = "arrow.up"
                let pathName = currentParentLabel.replacingOccurrences(of: "_", with: " ").capitalized

                if angleDifference > 45 {
                    instructionText = "Turn right onto \(pathName)"
                    iconName = "arrow.turn.up.right"
                } else if angleDifference > 30 {
                    instructionText = "Bear right onto \(pathName)"
                    iconName = "arrow.up.right"
                } else if angleDifference < -45 {
                    instructionText = "Turn left onto \(pathName)"
                    iconName = "arrow.turn.up.left"
                } else if angleDifference < -30 {
                    instructionText = "Bear left onto \(pathName)"
                    iconName = "arrow.up.left"
                } else {
                    instructionText = "Continue straight onto \(pathName)"
                }
                
                if !isFirstTurnSkipped {
                    isFirstTurnSkipped = true
                } else {
                    steps.append(DirectionStep(point: currentPoint, instruction: instructionText, iconName: iconName))
                }
                
                lastParentLabel = currentParentLabel
            }
        }
        
        steps.append(DirectionStep(point: path.last!, instruction: "You have arrived at your destination.", iconName: "mappin.circle.fill"))
        
        print("--- Generated \(steps.count) Directional Steps ---")
        for step in steps {
            print("  - \(step.instruction)")
        }
        
        return steps
    }
}

