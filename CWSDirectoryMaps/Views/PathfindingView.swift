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

// ✅ A new struct to hold both a location's name and its floor
struct Location: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let floor: Floor
}

// MARK: - Reusable Search Bar View
struct SearchBarView: View {
    @Binding var text: String
    let placeholder: String
    let locations: [Location] // Changed from [String]
    @State private var isEditing = false
    
    var onLocationSelected: (Location) -> Void // Changed from (String) -> Void
    
    var field: Field
    @FocusState.Binding var focusedField: Field?
    
    var body: some View {
        VStack(alignment: .leading) {
            // ... The HStack with the TextField is unchanged ...
            HStack {
                TextField(placeholder, text: $text)
                    .padding(7)
                    .padding(.horizontal, 25)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .autocorrectionDisabled(true)
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
                // This filtering and list logic is updated
                List(locations.filter { $0.name.lowercased().contains(text.lowercased()) || text.isEmpty }, id: \.self) { location in
                    Text(location.name) // Display the location's name
                        .onTapGesture {
                            self.text = location.name // Set text field to the name
                            self.isEditing = false
                            self.onLocationSelected(location) // Pass the whole Location object back
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
    @State private var pathWithLabels: [(point: CGPoint, label: String)] = []
    
    // UI State
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    @State private var manualOffsetX: CGFloat = 14.0
    @State private var manualOffsetY: CGFloat = 16.0
    @State private var unifiedGraph: [String: GraphNode] = [:]
    
    @State private var allLocations: [Location] = [] // ✅ Add this master list
    
    // 👇 Add these two lines
    @State private var startFloor: Floor = .ground
    @State private var endFloor: Floor = .ground
    
    
    @State private var startLabel: String = "braun_buffel-5"
    @State private var endLabel: String = "coach-1"
    
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
                        // For the START search bar
                        SearchBarView(text: $startLabel, placeholder: "Start", locations: allLocations, onLocationSelected: { selectedLocation in
                            self.startLabel = selectedLocation.name   // Set the name
                            self.startFloor = selectedLocation.floor   // ✅ SET THE CORRECT FLOOR
                            runPathfinding()
                        }, field: .start, focusedField: $focusedField)
                        
                        // DESTINATION Search Bar (Updated)
                        SearchBarView(text: $endLabel, placeholder: "Destination", locations: allLocations, onLocationSelected: { selectedLocation in
                            self.endLabel = selectedLocation.name     // Set the name
                            self.endFloor = selectedLocation.floor     // ✅ SET THE CORRECT FLOOR
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
                                                
                                                if pathWithLabels.count > 1 {
                                                    Path { path in
                                                        // Start the path at the first point
                                                        path.move(to: pathWithLabels[0].point)
                                                        
                                                        // Loop through the rest of the points
                                                        for i in 1..<pathWithLabels.count {
                                                            let prevLabel = pathWithLabels[i-1].label
                                                            let currentLabel = pathWithLabels[i].label
                                                            
                                                            // Get the full nodes from the unified graph
                                                            guard let prevNode = unifiedGraph[prevLabel],
                                                                  let currentNode = unifiedGraph[currentLabel] else {
                                                                // If a node isn't found, just move to the next point without drawing
                                                                path.move(to: pathWithLabels[i].point)
                                                                continue
                                                            }
                                                            
                                                            // 🧠 THE CORE LOGIC:
                                                            // Only draw a line if the nodes are on the same floor.
                                                            if prevNode.floor == currentNode.floor {
                                                                // Floors match, draw the line
                                                                path.addLine(to: pathWithLabels[i].point)
                                                            } else {
                                                                // This is a jump between floors, so DON'T draw.
                                                                // Instead, move the "pen" to the start of the next segment.
                                                                path.move(to: pathWithLabels[i].point)
                                                            }
                                                        }
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
    
    private func buildUnifiedGraph() {
        print("🛠️ Building unified graph via code...")
        var combinedGraph: [String: GraphNode] = [:]
        var connectionNodes: [String: [GraphNode]] = [:] // [connectionId: [Nodes]]
        
        // 1. ✅ DEFINE CONNECTIONS IN CODE
        // This map links node labels to a shared, unique connection ID.
        let connectionMap: [String: String] = [
            "escalator_bw_basement_1-0": "escalator_basement",
            "escalator_bw_basement_1": "escalator_basement",
            "escalator_west-4": "escalator_west",
            "lift_west-0": "lift_west",
            "lift_west": "lift_west"
        ]
        
        // 2. Combine all nodes and edges from all floors
        for (floor, data) in floorData {
            let floorPrefix = floor.fileName // "ground_path" or "lowerground_path"
            let labelGraph = buildLabelGraph(from: data.graph)
            
            for (label, var node) in labelGraph {
                // Create a new, unique label for each node: e.g., "ground_path_tissot-5"
                let uniqueLabel = "\(floorPrefix)_\(label)"
                node.label = uniqueLabel
                node.floor = floor
                
                // Remap neighbors to have unique labels as well
                node.neighbors = node.neighbors.map { neighbor in
                    return (node: "\(floorPrefix)_\(neighbor.node)", cost: neighbor.cost)
                }
                
                // 3. ✅ PROGRAMMATICALLY IDENTIFY CONNECTION POINTS
                // Check if the original label is in our connection map
                if let connectionId = connectionMap[label] {
                    // Assign the connectionId to the node
                    node.connectionId = connectionId
                    connectionNodes[connectionId, default: []].append(node)
                }
                
                combinedGraph[uniqueLabel] = node
            }
        }
        
        // 4. Add edges between floors at the connection points
        for (_, nodes) in connectionNodes {
            guard nodes.count > 1 else { continue }
            
            for i in 0..<nodes.count {
                for j in (i + 1)..<nodes.count {
                    let nodeA = nodes[i]
                    let nodeB = nodes[j]
                    
                    // Add a "cost" for changing floors (e.g., time to walk up stairs)
                    let costOfChangingFloors = 50.0
                    
                    combinedGraph[nodeA.label]?.neighbors.append((node: nodeB.label, cost: costOfChangingFloors))
                    combinedGraph[nodeB.label]?.neighbors.append((node: nodeA.label, cost: costOfChangingFloors))
                }
            }
        }
        
        self.unifiedGraph = combinedGraph
        print("✅ Unified graph built with \(self.unifiedGraph.count) nodes.")
        
        // 👇 ADD THIS DEBUGGING CODE
        print("\n--- Verifying Connections ---")
        for (id, nodes) in connectionNodes {
            print("Connection ID: \(id)")
            for node in nodes {
                if let graphNode = self.unifiedGraph[node.label] {
                    print("  - Node: \(graphNode.label)")
                    for neighbor in graphNode.neighbors {
                        print("    -> Neighbor: \(neighbor.node)")
                    }
                }
            }
        }
        print("---------------------------\n")
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
                
                // 👇 Replace the old allLocations logic with this new logic
                var combinedLocations: [Location] = []
                for (floor, data) in floorData {
                    for locationName in data.locations {
                        combinedLocations.append(Location(name: locationName, floor: floor))
                    }
                }
                // Remove duplicates and sort by name
                self.allLocations = Array(Set(combinedLocations)).sorted { $0.name < $1.name }
                
                switchToFloor(selectedFloor)
                buildUnifiedGraph()
                
                print("🎉 All floor data preloaded. \(self.allLocations.count) total locations available.")
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
                        label: node.label ?? node.id, parentLabel: node.parentLabel, connectionId: node.connectionId)
        }
        
        let normalizedNodes = foldedNodes.map { node -> Node in
            return Node(id: node.id,
                        x: node.x + offsetX,
                        y: node.y,
                        type: node.type,
                        rx: node.rx, ry: node.ry, angle: node.angle,
                        label: node.label ?? node.id, parentLabel: node.parentLabel, connectionId: node.connectionId)
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
//        pathWithLabels = []
        directionSteps = []
        
        // Set new floor data
        currentGraph = data.graph
        currentLocations = data.locations
        
        // Clear search fields when switching floors
        //        startLabel = ""
        //        endLabel = ""
        
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
        // 1. Guard against missing data
        guard !unifiedGraph.isEmpty,
              !startLabel.isEmpty,
              !endLabel.isEmpty else {
            pathWithLabels = [] // Clear old path
            directionSteps = []
            return
        }
        
        // 2. Create the unique start and end labels using the floor info
        //    e.g., "ground_path_braun_buffel-5" or "lowerground_path_tissot-5"
        let uniqueStartLabel = "\(startFloor.fileName)_\(startLabel)"
        let uniqueEndLabel = "\(endFloor.fileName)_\(endLabel)"
        
        print("🏃‍♂️ Running pathfinding from \(uniqueStartLabel) to \(uniqueEndLabel)")
        
        Task(priority: .userInitiated) {
            // 3. Call A* on the single unified graph
            let foundPathData = aStarByLabel(
                graph: self.unifiedGraph,
                startLabel: uniqueStartLabel,
                goalLabel: uniqueEndLabel
            )
            
            await MainActor.run {
                if let path = foundPathData {
                    print("✅ Multi-floor path found! It has \(path.count) points.")
                    self.pathWithLabels = path // ✅ Store the new path data
                    self.directionSteps = []
                    
                } else {
                    print("❌ No multi-floor path found.")
                    self.pathWithLabels = [] // ✅ Clear the path data
                    self.directionSteps = []
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    PathfindingView()
}
