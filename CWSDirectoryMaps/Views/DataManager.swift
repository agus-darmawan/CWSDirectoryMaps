//
//  DataManager.swift
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 02/09/25.
//

import Foundation
import SwiftUI

// MARK: - Data Manager
class DataManager: ObservableObject {
    @Published var floorData: [Floor: FloorData] = [:]
    @Published var unifiedGraph: [String: GraphNode] = [:]
    @Published var allLocations: [Location] = []
    @Published var isLoading = true
    
    // MARK: - Public Methods
    // In DataManager.swift

    func preloadAllFloorData() async {
        print("Starting to preload all floor data...")
        
        // Step 1: Load JSONs (raw data per floor)
        var loadedData: [Floor: FloorData] = [:]
        for floor in Floor.allCases {
            if let data = await loadFloorData(for: floor) {
                loadedData[floor] = data
                print("📥 Loaded data for \(floor.rawValue) with \(data.graph.nodes.count) nodes and \(data.locations.count) locations.")
            } else {
                print("⚠️ Failed to load data for \(floor.rawValue)")
            }
        }
        
        // Step 2: Process into unifiedGraph + combinedLocations
        let processedResult = await Task.detached(priority: .userInitiated) {
            let unifiedGraph = self.buildUnifiedGraph(from: loadedData)
            
            var combinedLocations: [Location] = []
            for (floor, data) in loadedData {
                for locationName in data.locations {
                    combinedLocations.append(Location(name: locationName, floor: floor))
                }
            }
            let sortedLocations = Array(Set(combinedLocations)).sorted { $0.name < $1.name }
            
            return (graph: unifiedGraph, locations: sortedLocations, floorData: loadedData)
        }.value
        
        // Step 3: Assign back to main thread
        await MainActor.run {
            self.unifiedGraph = processedResult.graph
            self.allLocations = processedResult.locations
            self.floorData = processedResult.floorData
            self.isLoading = false
            
            print("✅ Unified graph built with \(self.unifiedGraph.count) nodes total.")
            for (floor, data) in self.floorData {
                print("   • \(floor.rawValue): \(data.graph.nodes.count) nodes, \(data.locations.count) locations")
            }
            print("✅ All floor data preloaded. \(self.allLocations.count) total locations available.")
        }
    }
    
    func getFloorData(for floor: Floor) -> FloorData? {
        return floorData[floor]
    }
    
    // MARK: - Private Methods
    private func loadFloorData(for floor: Floor) async -> FloorData? {
        guard let url = Bundle.main.url(forResource: floor.fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let graph = try? JSONDecoder().decode(Graph.self, from: data) else {
            return nil
        }
        
        let processedGraph = processGraph(graph)
        let locations = extractLocations(from: processedGraph)
        
        return FloorData(graph: processedGraph, locations: locations)
    }
    
    func processGraph(_ graph: Graph) -> Graph {
        let xs = graph.nodes.map { $0.x }
        guard let minX = xs.min() else { return graph }
        let offsetX = minX < 0 ? -minX : 0
        
        let foldedNodes = graph.nodes.map { node -> Node in
            return Node(id: node.id, x: node.x, y: abs(node.y), type: node.type,
                        rx: node.rx, ry: node.ry, angle: node.angle,
                        label: node.label ?? node.id, parentLabel: node.parentLabel, 
                        connectionId: node.connectionId)
        }
        
        let normalizedNodes = foldedNodes.map { node -> Node in
            return Node(id: node.id,
                        x: node.x + offsetX,
                        y: node.y,
                        type: node.type,
                        rx: node.rx, ry: node.ry, angle: node.angle,
                        label: node.label ?? node.id, parentLabel: node.parentLabel, 
                        connectionId: node.connectionId)
        }
        
        return Graph(metadata: graph.metadata, nodes: normalizedNodes, edges: graph.edges)
    }
    
    func extractLocations(from graph: Graph) -> [String] {
        return Set(graph.nodes
            .filter { $0.type == "ellipse-center" || $0.type == "circle-center" || $0.type == "rect-corner" }
            .compactMap { $0.parentLabel ?? $0.label }
        ).sorted()
    }
    
    // In DataManager.swift

    // This function now takes data as an argument and returns the result.
    func buildUnifiedGraph(from floorData: [Floor: FloorData]) -> [String: GraphNode] {
        print("Building unified graph...")
        var combinedGraph: [String: GraphNode] = [:]
        var connectionNodes: [String: [GraphNode]] = [:]

        // Define connections in code
        let connectionMap: [String: String] = [
            "escalator_mid_bw_to_g": "escalator_mid_bw",
            "escalator_mid_bw_to_lg": "escalator_mid_bw",
            "escalator_west_bw_to_g": "escalator_west_bw",
            "escalator_west_bw_to_lg": "escalator_west_bw",
            "lift_west_to_g": "lift_west",
            "lift_west_to_lg": "lift_west"
        ]


        for (floor, data) in floorData {
            let floorPrefix = floor.fileName
            let labelGraph = buildLabelGraph(from: data.graph)

            for (label, var node) in labelGraph {
                let uniqueLabel = "\(floorPrefix)_\(label)"
                node.label = uniqueLabel
                node.floor = floor

                node.neighbors = node.neighbors.map { neighbor in
                    return (node: "\(floorPrefix)_\(neighbor.node)", cost: neighbor.cost)
                }

                if let connectionId = connectionMap[label] {
                    node.connectionId = connectionId
                        // store a copy with the prefixed label
                        var prefixedNode = node
                        prefixedNode.label = uniqueLabel
                        connectionNodes[connectionId, default: []].append(prefixedNode)
                    print("✅ Connected: \(uniqueLabel) → connectionId=\(connectionId)")
                } else if label.lowercased().contains("escalator") || label.lowercased().contains("lift") {
                    print("⚠️ Potential connector not in map: \(uniqueLabel) (raw label: \(label))")
                }

                combinedGraph[uniqueLabel] = node
            }
        }


        // Build cross-floor links with debugging
        for (connectionId, nodes) in connectionNodes {
            guard nodes.count > 1 else {
                print("ℹ️ connectionId=\(connectionId) has only one node → no cross-floor link made.")
                continue
            }

            print("🔗 Building cross-floor links for connectionId=\(connectionId) with \(nodes.count) node(s):")
            for n in nodes {
                print("   • \(n.label) (\(n.floor?.rawValue))")
            }

            for i in 0..<nodes.count {
                for j in (i + 1)..<nodes.count {
                    let nodeA = nodes[i]
                    let nodeB = nodes[j]
                    let costOfChangingFloors = 50.0 // Arbitrary high cost for floor changes

                    combinedGraph[nodeA.label]?.neighbors.append((node: nodeB.label, cost: costOfChangingFloors))
                    combinedGraph[nodeB.label]?.neighbors.append((node: nodeA.label, cost: costOfChangingFloors))

                    print("   ✅ Linked \(nodeA.label) ↔ \(nodeB.label) (cost=\(costOfChangingFloors))")
                }
            }
        }

        // Post-check: list neighbors for all connection nodes
        print("🔍 Verifying neighbors for connection nodes:")
        for (connectionId, nodes) in connectionNodes {
            for node in nodes {
                if let gNode = combinedGraph[node.label] {
                    let neighborLabels = gNode.neighbors.map { $0.node }
                    print("   • \(node.label) neighbors: \(neighborLabels)")
                } else {
                    print("   • ⚠️ \(node.label) not found in combinedGraph")
                }
            }
        }

        // Instead of setting a class property, we return the completed graph.
        return combinedGraph
    }
}
