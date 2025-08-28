//
//  PathfindingView.swift
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 27/08/25.
//


import SwiftUI

// MARK: - PathfindingView
struct PathfindingView: View {
    @State private var graph: Graph? = nil
    @State private var path: [String] = [] // store A* path labels
    @State private var pathCoordinates: [CGPoint] = [] // precomputed coordinates for drawing
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let graph = graph {
                    let bounds = graphBounds(graph)
                    let scale = fittingScale(bounds: bounds, in: geo.size)
                    let offset = fittingOffset(bounds: bounds, in: geo.size, scale: scale)
                    
                    ZStack {
                        // MARK: - Draw edges
                        ForEach(graph.edges) { edge in
                            if let from = graph.nodes.first(where: { $0.id == edge.source }),
                               let to = graph.nodes.first(where: { $0.id == edge.target }) {
                                Path { path in
                                    path.move(to: CGPoint(x: from.x, y: from.y))
                                    path.addLine(to: CGPoint(x: to.x, y: to.y))
                                }
                                .stroke(Color.white.opacity(0.6), lineWidth: 5)
                            }
                        }
                        
                        // MARK: - Draw path
                        if pathCoordinates.count > 1 { // Changed condition
                            ForEach(0..<(pathCoordinates.count-1), id: \.self) { i in
                                Path { p in
                                    let from = pathCoordinates[i]
                                    let to = pathCoordinates[i+1]
                                    // REMOVED: * scale + offset.width/height from here
                                    p.move(to: CGPoint(x: from.x, y: from.y))
                                    p.addLine(to: CGPoint(x: to.x, y: to.y))
                                }
                                .stroke(Color.yellow, lineWidth: 6)
                            }
                        }
                        
                        // MARK: - Draw nodes
                        ForEach(graph.nodes) { node in
                            Circle()
                                .fill(color(for: node))
                                .frame(width: 6, height: 6)
                                .position(x: node.x, y: node.y)
                        }
                    }
                    .scaleEffect(scale, anchor: .topLeading)
                    .offset(offset)
                } else {
                    Text("Loading graph...")
                        .padding()
                        .foregroundColor(.white)
                }
            }
            .background(Color.black.opacity(0.9).ignoresSafeArea())
            .onAppear {
                loadAndPrepareGraph()
            }
        }
    }
    
    // MARK: - Node Coloring
    private func color(for node: Node) -> Color {
        switch node.type {
        case "ellipse-center": return .blue
        case "ellipse-point": return .green
        case "path-point": return .orange
        default: return .red
        }
    }
    
    // MARK: - Graph Bounds Helpers
    private func graphBounds(_ graph: Graph) -> CGRect {
        let xs = graph.nodes.map { $0.x }
        let ys = graph.nodes.map { $0.y }
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return .zero
        }
        return CGRect(x: minX, y: minY,
                      width: maxX - minX,
                      height: maxY - minY)
    }
    
    private func fittingScale(bounds: CGRect, in size: CGSize) -> CGFloat {
        guard bounds.width > 0, bounds.height > 0 else { return 1 }
        let scaleX = size.width / bounds.width
        let scaleY = size.height / bounds.height
        return min(scaleX, scaleY) * 0.95
    }
    
    private func fittingOffset(bounds: CGRect, in size: CGSize, scale: CGFloat) -> CGSize {
        let graphWidth = bounds.width * scale
        let graphHeight = bounds.height * scale
        let x = (size.width - graphWidth) / 2 - bounds.minX * scale
        let y = (size.height - graphHeight) / 2 - bounds.minY * scale
        return CGSize(width: x, height: y)
    }
    
    // MARK: - Graph Loading and Pathfinding
    private func loadAndPrepareGraph() {
        guard let g = loadGraph() else { return }
        
        // 1️⃣ Ensure all nodes have labels
        let nodesWithLabel = g.nodes.map { node -> Node in
            if node.label == nil {
                return Node(id: node.id, x: node.x, y: node.y, type: node.type,
                            rx: node.rx, ry: node.ry, angle: node.angle,
                            label: node.id, parentLabel: node.parentLabel)
            }
            return node
        }
        
        // 2️⃣ Recreate graph with labeled nodes
        let labeledGraph = Graph(metadata: g.metadata, nodes: nodesWithLabel, edges: g.edges)
        self.graph = labeledGraph
        
        // 3️⃣ Build label-based graph for A*
        let labelGraph = buildLabelGraph(from: labeledGraph)
        
        // 4️⃣ Run A*
        let start = "braun_buffel"
        let goal = "oval_atrium"
        if let foundPathCoordinates = aStarByLabel(graph: labelGraph, startLabel: start, goalLabel: goal) {
            self.pathCoordinates = foundPathCoordinates // Assign coordinates directly
            print("✅ Path found from \(start) to \(goal).")
            for (index, coordinate) in self.pathCoordinates.enumerated() {
//                print("  [\(index)] X: \(String(format: "%.1f", coordinate.x)), Y: \(String(format: "%.1f", coordinate.y))")
            }
        } else {
            print("❌ No path found from \(start) to \(goal)")
        }
    }
}

// MARK: - Preview
#Preview {
    PathfindingView()
}
