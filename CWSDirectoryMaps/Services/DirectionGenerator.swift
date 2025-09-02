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
    
    // MARK: - Private Helpers

    private func angle(from start: CGPoint, to end: CGPoint) -> CGFloat {
        return atan2(end.y - start.y, end.x - start.x)
    }

    private func key(for point: CGPoint) -> String {
        return "\(point.x),\(point.y)"
    }
    
    /// Finds the two endpoints of a path segment by looking for nodes labeled with "_point_0" and "_point_1".
    private func findSegmentEndpoints(for parentLabel: String, in graph: Graph) -> (start: Node?, end: Node?) {
        let allNodesInSegment = graph.nodes.filter { $0.parentLabel == parentLabel }
        let point0 = allNodesInSegment.first { $0.label?.hasSuffix("_point_0") == true }
        let point1 = allNodesInSegment.first { $0.label?.hasSuffix("_point_1") == true }
        return (point0, point1)
    }
    
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        return hypot(a.x - b.x, a.y - b.y)
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

    // MARK: - Main Generation Function
    
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
            let prevNode = pathNodes[i-1]
            let currentNode = pathNodes[i]
            let nextNode = pathNodes[i+1]
            
            guard let currentParentLabel = currentNode.parentLabel else { continue }

            if currentParentLabel != lastParentLabel {
                let prevPoint = CGPoint(x: prevNode.x, y: prevNode.y)
                let currPoint = CGPoint(x: currentNode.x, y: currentNode.y)
                
                // Use corrected angle logic
                let (angleDifference, nextPoint) = correctedAngle(prev: prevPoint, curr: currPoint, pathNodes: pathNodes, index: i)
                
                // --- Improved Debug Output ---
                print("-> Angle check: \(prevNode.id) -> \(currentNode.id) -> \(nextNode.id)  (\(lastParentLabel ?? "Start") -> \(currentParentLabel)) = \(String(format: "%.1f", angleDifference))°")
                print("     prev: \(prevPoint), curr: \(currPoint), next: \(nextPoint)")
                // -----------------------------

                let angleThreshold: CGFloat = 30.0
                var instructionText = ""
                var iconName = "arrow.up"
                let pathName = currentParentLabel.replacingOccurrences(of: "_", with: " ").capitalized

                if angleDifference > 60 {
                    instructionText = "Turn right onto \(pathName)"
                    iconName = "arrow.turn.up.right"
                } else if angleDifference > angleThreshold {
                    instructionText = "Bear right onto \(pathName)"
                    iconName = "arrow.up.right"
                } else if angleDifference < -60 {
                    instructionText = "Turn left onto \(pathName)"
                    iconName = "arrow.turn.up.left"
                } else if angleDifference < -angleThreshold {
                    instructionText = "Bear left onto \(pathName)"
                    iconName = "arrow.up.left"
                } else {
                    instructionText = "Continue onto \(pathName)"
                }
                
                if !isFirstTurnSkipped {
                    isFirstTurnSkipped = true
                } else {
                    if !instructionText.isEmpty {
                        steps.append(DirectionStep(point: currPoint, instruction: instructionText, iconName: iconName))
                    }
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
