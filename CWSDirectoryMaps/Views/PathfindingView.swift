//
//  PathfindingView.swift
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 27/08/25.
//


import SwiftUI

// MARK: - Field Enum for Focus State
enum Field: Hashable {
    case start
    case destination
}

// MARK: - Reusable Search Bar View
struct SearchBarView: View {
    @Binding var text: String
    let placeholder: String
    let locations: [String]
    @State private var isEditing = false
    
    var onLocationSelected: (String) -> Void
    
    var field: Field
    @FocusState.Binding var focusedField: Field?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                TextField(placeholder, text: $text)
                    .padding(7)
                    .padding(.horizontal, 25)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 8)
                        }
                    )
                    .focused($focusedField, equals: field)
                    .onTapGesture {
                        self.isEditing = true
                        self.focusedField = field
                    }
            }
            .padding(.horizontal, 10)

            if isEditing {
                List(locations.filter { $0.lowercased().contains(text.lowercased()) || text.isEmpty }, id: \.self) { location in
                    Text(location)
                        .onTapGesture {
                            self.text = location
                            self.isEditing = false
                            self.onLocationSelected(location)
                            self.focusedField = nil
                        }
                }
                .listStyle(PlainListStyle())
                .frame(maxHeight: 200)
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - View for a Single Direction Step
struct DirectionStepView: View {
    let step: DirectionStep

    var body: some View {
        HStack {
            Image(systemName: step.iconName)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40)
            
            Text(step.instruction)
                .foregroundColor(.white)
                .font(.body)
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.8))
        .cornerRadius(10)
    }
}


// MARK: - PathfindingView
struct PathfindingView: View {
    @State private var graph: Graph? = nil
    @State private var pathCoordinates: [CGPoint] = []
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @State private var manualOffsetX: CGFloat = 14.0
    @State private var manualOffsetY: CGFloat = 16.0
    
    @State private var startLabel: String = "metro"
    @State private var endLabel: String = "east_lobby"
    @State private var allLocations: [String] = []
    
    @State private var directionSteps: [DirectionStep] = []
    private let directionsGenerator = DirectionsGenerator()
    private let pathCleaner = PathCleaner() // Create an instance of the new cleaner
    
    @FocusState private var focusedField: Field?
    
    var body: some View {
        VStack(spacing: 0) {
            VStack {
                SearchBarView(text: $startLabel, placeholder: "Start", locations: allLocations, onLocationSelected: { selected in
                    self.startLabel = selected
                    runPathfinding()
                }, field: .start, focusedField: $focusedField)
                
                SearchBarView(text: $endLabel, placeholder: "Destination", locations: allLocations, onLocationSelected: { selected in
                    self.endLabel = selected
                    runPathfinding()
                }, field: .destination, focusedField: $focusedField)
            }
            .padding(.top)
            .background(Color.black.opacity(0.8))

            ZStack {
                // --- Map View ---
                ZStack {
                    Image("map_background")
                        .resizable()
                        .scaledToFit()
                        .overlay(
                            GeometryReader { imageGeo in
                                if let graph = graph {
                                    let bounds = graphBounds(graph)
                                    let overlayScale = fittingScale(bounds: bounds, in: imageGeo.size)
                                    let overlayOffset = fittingOffset(bounds: bounds, in: imageGeo.size, scale: overlayScale)

                                    ZStack {
                                        ForEach(graph.edges) { edge in
                                            if let from = graph.nodes.first(where: { $0.id == edge.source }),
                                               let to = graph.nodes.first(where: { $0.id == edge.target }) {
                                                Path { path in
                                                    path.move(to: CGPoint(x: from.x, y: from.y))
                                                    path.addLine(to: CGPoint(x: to.x, y: to.y))
                                                }
                                                .stroke(Color.white.opacity(0.6), lineWidth: 2 / self.scale)
                                            }
                                        }
                                        
                                        if pathCoordinates.count > 1 {
                                            Path { path in
                                                path.addLines(pathCoordinates)
                                            }
                                            .stroke(Color.yellow, lineWidth: 4 / self.scale)
                                        }
                                        
                                        ForEach(graph.nodes) { node in
                                            Circle()
                                                .fill(color(for: node))
                                                .frame(width: 4 / self.scale, height: 4 / self.scale)
                                                .position(x: node.x, y: node.y)
                                        }
                                    }
                                    .scaleEffect(overlayScale, anchor: .topLeading)
                                    .offset(x: overlayOffset.width + manualOffsetX, y: overlayOffset.height + manualOffsetY)
                                }
                            }
                        )
                }
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            self.offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            self.lastOffset = self.offset
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / self.lastScale
                            self.scale *= delta
                            self.lastScale = value
                        }
                        .onEnded { _ in
                            self.lastScale = 1.0
                        }
                )

                if graph == nil {
                    Text("Loading graph...")
                        .padding()
                        .foregroundColor(.white)
                }
                
                // --- Directions UI ---
                VStack {
                    Spacer()
                    if !directionSteps.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(directionSteps) { step in
                                    DirectionStepView(step: step)
                                }
                            }
                            .padding()
                        }
                        .frame(height: 100)
                        .background(Color.black.opacity(0.7))
                    }
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            loadAndPrepareGraph()
        }
    }
    
    private func color(for node: Node) -> Color {
        return .white
    }

    private func graphBounds(_ graph: Graph) -> CGRect {
        let xs = graph.nodes.map { $0.x }
        let ys = graph.nodes.map { $0.y }
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return .zero
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func fittingScale(bounds: CGRect, in size: CGSize) -> CGFloat {
        guard bounds.width > 0, bounds.height > 0 else { return 1 }
        let scaleX = size.width / bounds.width
        let scaleY = size.height / bounds.height
        return min(scaleX, scaleY)
    }

    private func fittingOffset(bounds: CGRect, in size: CGSize, scale: CGFloat) -> CGSize {
        let graphWidth = bounds.width * scale
        let graphHeight = bounds.height * scale
        let x = (size.width - graphWidth) / 2 - bounds.minX * scale
        let y = (size.height - graphHeight) / 2 - bounds.minY * scale
        return CGSize(width: x, height: y)
    }
    
    private func runPathfinding() {
        guard let graph = self.graph else { return }
        
        Task(priority: .userInitiated) {
            let labelGraph = buildLabelGraph(from: graph)
            let foundPathCoordinates = aStarByLabel(graph: labelGraph, startLabel: self.startLabel, goalLabel: self.endLabel)
            
            await MainActor.run {
                if let path = foundPathCoordinates {
                    
                    // --- MODIFICATION: Clean the path before generating directions ---
                    let cleanedPath = pathCleaner.clean(path: path, graph: graph)
                    self.pathCoordinates = cleanedPath // Use the cleaned path for drawing
                    self.directionSteps = directionsGenerator.generate(from: cleanedPath, graph: self.graph)
                    // --- END MODIFICATION ---

                    print("✅ Path found from \(startLabel) to \(endLabel).")
                    
                    // --- DEBUGGING: Print the final generated direction steps ---
                    print("--- Final Directional Steps ---")
                    for (index, step) in self.directionSteps.enumerated() {
                        print("Step \(index + 1): \(step.instruction)")
                    }
                    print("-----------------------------")
                    // --- END DEBUGGING ---
                    
                } else {
                    self.pathCoordinates = []
                    self.directionSteps = []
                    print("❌ No path found from \(startLabel) to \(endLabel)")
                }
            }
        }
    }

    private func loadAndPrepareGraph() {
        Task {
            guard let g = loadGraph() else { return }

            let xs = g.nodes.map { $0.x }
            guard let minX = xs.min() else { return }
            let offsetX = minX < 0 ? -minX : 0
            
            let foldedNodes = g.nodes.map { node -> Node in
                return Node(id: node.id, x: node.x, y: abs(node.y), type: node.type,
                            rx: node.rx, ry: node.ry, angle: node.angle,
                            label: node.label ?? node.id, parentLabel: node.parentLabel)
            }

            let foldedYs = foldedNodes.map { $0.y }
            guard let newMaxY = foldedYs.max() else { return }

            let normalizedNodes = foldedNodes.map { node -> Node in
                return Node(id: node.id, x: node.x + offsetX, y: newMaxY - node.y, type: node.type,
                            rx: node.rx, ry: node.ry, angle: node.angle,
                            label: node.label ?? node.id, parentLabel: node.parentLabel)
            }
            
            let correctedGraph = Graph(metadata: g.metadata, nodes: normalizedNodes, edges: g.edges)
            
            let locations = Set(correctedGraph.nodes
                .filter { $0.type == "ellipse-center" || $0.type == "circle-center" || $0.type == "rect-corner" }
                .compactMap { $0.parentLabel ?? $0.label }
            ).sorted()
            
            await MainActor.run {
                self.graph = correctedGraph
                self.allLocations = locations
                runPathfinding()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    PathfindingView()
}

