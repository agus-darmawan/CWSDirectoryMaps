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

// MARK: - Floor Enum
enum Floor: String, CaseIterable, Identifiable {
    case ground = "Ground"
    case lowerground = "Lower Ground"
    
    var id: String { rawValue }
    
    var fileName: String {
        switch self {
        case .ground:
            return "ground_path"
        case .lowerground:
            return "lowerground_path"
        }
    }
}

// MARK: - Graph Container for Preloaded Data
struct FloorData {
    let graph: Graph
    let locations: [String]
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
    // Preloaded data for both floors
    @State private var floorData: [Floor: FloorData] = [:]
    @State private var isLoading = true
    
    // Current active data
    @State private var currentGraph: Graph? = nil
    @State private var currentLocations: [String] = []
    @State private var pathCoordinates: [CGPoint] = []
    
    // UI State
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @State private var manualOffsetX: CGFloat = 14.0
    @State private var manualOffsetY: CGFloat = 16.0
    
    @State private var startLabel: String = "braun_buffel-5"
    @State private var endLabel: String = "tissot-5"
    
    @State private var directionSteps: [DirectionStep] = []
    private let directionsGenerator = DirectionsGenerator()
    private let pathCleaner = PathCleaner()
    
    @FocusState private var focusedField: Field?
    
    // Floor selection
    @State private var selectedFloor: Floor = .ground
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                // Loading view
                VStack {
                    ProgressView("Loading maps...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                    Text("Preparing floor data...")
                        .foregroundColor(.white)
                        .font(.caption)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
            } else {
                // Main content
                VStack(spacing: 0) {
                    // Floor selector with manual buttons as backup
                    VStack {
                        Picker("Floor", selection: $selectedFloor) {
                            ForEach(Floor.allCases) { floor in
                                Text(floor.rawValue).tag(floor)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .task(id: selectedFloor) {
                            print("📱 Picker selection changed to: \(selectedFloor.rawValue)")
                            switchToFloor(selectedFloor)
                        }
                        
                        // Manual buttons as backup
                        HStack {
                            Button("Ground Floor") {
                                print("🔘 Manual Ground button pressed")
                                selectedFloor = .ground
                                switchToFloor(.ground)
                            }
                            .foregroundColor(selectedFloor == .ground ? .yellow : .white)
                            
                            Button("Lower Ground") {
                                print("🔘 Manual Lower Ground button pressed")
                                selectedFloor = .lowerground
                                switchToFloor(.lowerground)
                            }
                            .foregroundColor(selectedFloor == .lowerground ? .yellow : .white)
                        }
                        .font(.caption)
                    }
                    
                    VStack {
                        SearchBarView(text: $startLabel, placeholder: "Start", locations: currentLocations, onLocationSelected: { selected in
                            self.startLabel = selected
                            runPathfinding()
                        }, field: .start, focusedField: $focusedField)
                        
                        SearchBarView(text: $endLabel, placeholder: "Destination", locations: currentLocations, onLocationSelected: { selected in
                            self.endLabel = selected
                            runPathfinding()
                        }, field: .destination, focusedField: $focusedField)
                    }
                    .padding(.top)
                    .background(Color.black.opacity(0.8))
                    .padding()

                    ZStack {
                        // --- Map View ---
                        ZStack {
                            Image("map_background")
                                .resizable()
                                .scaledToFit()
                                .overlay(
                                    GeometryReader { imageGeo in
                                        if let graph = currentGraph {
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
                                            .offset(overlayOffset)
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

                        if currentGraph == nil {
                            Text("No graph data available")
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
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            preloadAllFloorData()
        }
    }
    
    // MARK: - Preload All Floor Data
    private func preloadAllFloorData() {
        Task {
            print("🔄 Starting to preload all floor data...")
            
            var loadedData: [Floor: FloorData] = [:]
            
            // Load data for all floors
            for floor in Floor.allCases {
                if let data = await loadFloorData(for: floor) {
                    loadedData[floor] = data
                    print("✅ Loaded data for \(floor.rawValue)")
                } else {
                    print("❌ Failed to load data for \(floor.rawValue)")
                }
            }
            
            await MainActor.run {
                self.floorData = loadedData
                self.isLoading = false
                
                // Set initial floor data
                switchToFloor(selectedFloor)
                print("🎉 All floor data preloaded successfully!")
            }
        }
    }
    
    // MARK: - Load Individual Floor Data
    private func loadFloorData(for floor: Floor) async -> FloorData? {
        guard let url = Bundle.main.url(forResource: floor.fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let graph = try? JSONDecoder().decode(Graph.self, from: data) else {
            return nil
        }
        
        // Process the graph (same logic as before)
        let processedGraph = processGraph(graph)
        let locations = extractLocations(from: processedGraph)
        
        return FloorData(graph: processedGraph, locations: locations)
    }
    
    // MARK: - Process Graph (extracted from previous logic)
    private func processGraph(_ graph: Graph) -> Graph {
        let xs = graph.nodes.map { $0.x }
        guard let minX = xs.min() else { return graph }
        let offsetX = minX < 0 ? -minX : 0
        
        let foldedNodes = graph.nodes.map { node -> Node in
            return Node(id: node.id, x: node.x, y: abs(node.y), type: node.type,
                        rx: node.rx, ry: node.ry, angle: node.angle,
                        label: node.label ?? node.id, parentLabel: node.parentLabel)
        }
        
        let normalizedNodes = foldedNodes.map { node -> Node in
            return Node(id: node.id,
                        x: node.x + offsetX,
                        y: node.y,
                        type: node.type,
                        rx: node.rx, ry: node.ry, angle: node.angle,
                        label: node.label ?? node.id, parentLabel: node.parentLabel)
        }
        
        return Graph(metadata: graph.metadata, nodes: normalizedNodes, edges: graph.edges)
    }
    
    // MARK: - Extract Locations from Graph
    private func extractLocations(from graph: Graph) -> [String] {
        return Set(graph.nodes
            .filter { $0.type == "ellipse-center" || $0.type == "circle-center" || $0.type == "rect-corner" }
            .compactMap { $0.parentLabel ?? $0.label }
        ).sorted()
    }
    
    // MARK: - Switch to Floor (Instant since data is preloaded)
    private func switchToFloor(_ floor: Floor) {
        print("🔄 switchToFloor called with: \(floor.rawValue)")
        print("📊 Available preloaded floors: \(floorData.keys.map { $0.rawValue })")
        
        guard let data = floorData[floor] else {
            print("❌ No preloaded data for \(floor.rawValue)")
            print("💾 floorData contents: \(floorData)")
            return
        }
        
        print("🔄 Switching to \(floor.rawValue)")
        
        // Reset view state for new floor
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
        pathCoordinates = []
        directionSteps = []
        
        // Set new floor data
        currentGraph = data.graph
        currentLocations = data.locations
        
        // Clear search fields when switching floors
        startLabel = ""
        endLabel = ""
        
        print("✅ Successfully switched to \(floor.rawValue)")
        print("📍 Available locations: \(currentLocations.count)")
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
        guard let graph = self.currentGraph,
              !startLabel.isEmpty,
              !endLabel.isEmpty else {
            pathCoordinates = []
            directionSteps = []
            return
        }
        
        Task(priority: .userInitiated) {
            let labelGraph = buildLabelGraph(from: graph)
            let foundPathCoordinates = aStarByLabel(graph: labelGraph, startLabel: self.startLabel, goalLabel: self.endLabel)
            
            await MainActor.run {
                if let path = foundPathCoordinates {
                    // Clean the path before generating directions
                    let cleanedPath = pathCleaner.clean(path: path, graph: graph)
                    self.pathCoordinates = cleanedPath
                    self.directionSteps = directionsGenerator.generate(from: cleanedPath, graph: self.currentGraph)

                    print("✅ Path found from \(startLabel) to \(endLabel) on \(selectedFloor.rawValue).")
                    
                    // Debug: Print the final generated direction steps
                    print("--- Final Directional Steps ---")
                    for (index, step) in self.directionSteps.enumerated() {
                        print("Step \(index + 1): \(step.instruction)")
                    }
                    print("-----------------------------")
                    
                } else {
                    self.pathCoordinates = []
                    self.directionSteps = []
                    print("❌ No path found from \(startLabel) to \(endLabel) on \(selectedFloor.rawValue)")
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    PathfindingView()
}
