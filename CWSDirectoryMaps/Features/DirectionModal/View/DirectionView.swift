//
//  Enhanced DirectionView.swift
//  CWSDirectoryMaps
//
//  Enhanced with floor transition notifications and end route functionality
//

import SwiftUI

struct DirectionView: View {
    
    @EnvironmentObject var dataManager: DataManager
    @StateObject var pathfindingManager = PathfindingManager()
    
    let startLocation: Store
    @State var destinationStore: Store
    
    @State private var showDirectionsModal = true
    @State private var showStepsModal = false
    @State private var showSteps = false
    @State private var selectedTravelMode: TravelMode = .walk
    @State private var showFloorTransitionAlert = false
    @State private var transitionMessage = ""
    @State private var showEndRouteAlert = false
    @State private var currentFloor: Floor = .ground
    @Binding var showFloorChangeContent: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    @State var pathWithLabels: [(point: CGPoint, label: String)] = []
    
    var body: some View {
        ZStack {
            VStack {
                if pathWithLabels.isEmpty {
                    ProgressView("Calculating route...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    IntegratedMapView(
                        dataManager: dataManager,
                        pathWithLabels: $pathWithLabels,
                        pathfindingManager: pathfindingManager,
                        currentFloor: $currentFloor
                    )
                    .transition(.opacity)
                }
                Spacer()
                
                if showDirectionsModal {
                    EnhancedDirectionsModal(
                        destinationStore: destinationStore,
                        startLocation: startLocation,
                        showModal: $showDirectionsModal,
                        pathfindingManager: pathfindingManager,
                        selectedMode: $selectedTravelMode
                    ) {
                        showDirectionsModal = false
                        showStepsModal = true
                    }
                }
                
                if showStepsModal && !showSteps {
                    EnhancedDirectionStepsModal(
                        showStepsModal: $showStepsModal,
                        showSteps: $showSteps,
                        destinationStore: destinationStore,
                        pathfindingManager: pathfindingManager,
                        showFloorChangeContent: $showFloorChangeContent,
                        onEndRoute: {
                            showEndRouteAlert = true
                        },
                        currentFloor: $currentFloor
                    )
                }
            }
            
            if showStepsModal && showSteps {
                EnhancedDirectionStepsListView(
                    showStepsModal: $showStepsModal,
                    showSteps: $showSteps,
                    destinationStore: destinationStore,
                    pathfindingManager: pathfindingManager,
                    onEndRoute: {
                        showEndRouteAlert = true
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .ignoresSafeArea(.all, edges: .bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .bottom)
        .onAppear {
            runPathfinding()
            detectCurrentFloor()
        }
        .onReceive(pathfindingManager.$pathWithLabels) { newPath in
            self.pathWithLabels = newPath
        }
        .onReceive(pathfindingManager.$currentStepIndex) { newIndex in
            checkForFloorTransition()
        }
        .onChange(of: selectedTravelMode) { _, newMode in
            pathfindingManager.updateTravelMode(newMode)
        }
        // End route confirmation alert
        .alert("End Navigation", isPresented: $showEndRouteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Route", role: .destructive) {
                endRoute()
            }
        } message: {
            Text("Are you sure you want to end this navigation? You will return to the main directory.")
        }
    }
    
    private func runPathfinding() {
        guard let startLabel = startLocation.graphLabel,
              let endLabel = destinationStore.graphLabel else {
            print("Missing graph labels, cannot pathfind")
            return
        }
        
        pathfindingManager.updateTravelMode(selectedTravelMode)
        pathfindingManager.runPathfinding(
            startStore: startLocation,
            endStore: destinationStore,
            unifiedGraph: dataManager.unifiedGraph
        )
    }
    
    private func detectCurrentFloor() {
        if let startLabel = startLocation.graphLabel {
            currentFloor = extractFloorFromLabel(startLabel)
        }
    }
    
    private func checkForFloorTransition() {
        guard pathfindingManager.currentStepIndex < pathfindingManager.enhancedDirectionSteps.count else { return }
        
        let currentStep = pathfindingManager.enhancedDirectionSteps[pathfindingManager.currentStepIndex]
        let stepFloor = extractFloorFromLabel(getStepLabel(for: currentStep))
        
        if stepFloor != currentFloor {
            let transitionType = getTransitionType(from: currentFloor, to: stepFloor)
            transitionMessage = "Please use the \(transitionType) to go to \(stepFloor.displayName)"
            showFloorChangeContent = true
        }
    }
    
    private func getStepLabel(for step: EnhancedDirectionStep) -> String {
        // Find the corresponding path label for this step
        let stepPoint = step.point
        if let pathItem = pathWithLabels.first(where: {
            abs($0.point.x - stepPoint.x) < 1.0 && abs($0.point.y - stepPoint.y) < 1.0
        }) {
            return pathItem.label
        }
        return ""
    }
    
    private func getNextFloor() -> Floor? {
        guard pathfindingManager.currentStepIndex < pathfindingManager.enhancedDirectionSteps.count else { return nil }
        
        let currentStep = pathfindingManager.enhancedDirectionSteps[pathfindingManager.currentStepIndex]
        return extractFloorFromLabel(getStepLabel(for: currentStep))
    }
    
    private func getTransitionType(from: Floor, to: Floor) -> String {
        // Logic to determine if elevator or escalator should be used
        let floorDifference = abs(from.rawValue.count - to.rawValue.count)
        
        if floorDifference > 1 {
            return "elevator"
        } else {
            return "escalator"
        }
    }
    
    private func extractFloorFromLabel(_ label: String) -> Floor {
        if label.hasPrefix("ground_") { return .ground }
        if label.hasPrefix("lowerground_") { return .lowerGround }
        if label.hasPrefix("1st_") { return .first }
        if label.hasPrefix("2nd_") { return .second }
        if label.hasPrefix("3rd_") { return .third }
        if label.hasPrefix("4th_") { return .fourth }
        return .ground
    }
    
    private func endRoute() {
        dismiss()
    }
}

struct EnhancedDirectionsModal: View {
    @State var destinationStore: Store
    @State var startLocation: Store
    @Binding var showModal: Bool
    @ObservedObject var pathfindingManager: PathfindingManager
    @Binding var selectedMode: TravelMode
    
    var onGoTapped: (() -> Void)?
    
    var body: some View {
        if showModal {
            VStack(alignment: .trailing) {
                VStack(spacing: 16) {
                    // Title with real-time metrics
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Directions")
                                    .font(.title3)
                                    .bold()
                                Image(systemName: selectedMode.icon)
                            }
                            Text("\(pathfindingManager.formatDistance(pathfindingManager.totalDistance)) – \(pathfindingManager.formatTime(pathfindingManager.totalEstimatedTime))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Button(action: { showModal = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 12)
                    }
                    
                    // Enhanced mode selection
                    HStack {
                        ForEach(TravelMode.allCases, id: \.self) { mode in
                            Button {
                                selectedMode = mode
                                pathfindingManager.updateTravelMode(mode)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 18))
                                    Text(mode.rawValue.capitalized)
                                        .font(.caption)
                                }
                                .frame(width: 70, height: 50)
                                .background(
                                    selectedMode == mode ? Color.blue : Color.gray.opacity(0.2)
                                )
                                .foregroundColor(
                                    selectedMode == mode ? .white : .primary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Enhanced from-to section
                    ZStack {
                        VStack(spacing: 0) {
                            // from
                            HStack {
                                Image(systemName: "location.circle.fill")
                                    .foregroundColor(.blue)
                                Text(startLocation.name)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            
                            // to
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                Text(destinationStore.name)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Divider with swap button
                        Divider()
                            .frame(height: 1)
                            .padding(.leading, 36)
                            .padding(.trailing, 56)
                            .overlay(
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        swap(&startLocation, &destinationStore)
                                        // Re-run pathfinding with swapped locations
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            pathfindingManager.runPathfinding(
                                                startStore: startLocation,
                                                endStore: destinationStore,
                                                unifiedGraph: [:]
                                            )
                                        }
                                    }) {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.trailing, 16)
                                }
                            )
                    }
                    
                    // Enhanced GO button
                    Button(action: {
                        print("Go tapped - Starting navigation")
                        showModal = false
                        onGoTapped?()
                    }) {
                        HStack {
                            Text("START NAVIGATION")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.green.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16, corners: [.topLeft, .topRight])
                .frame(height: 320)
            }
            .ignoresSafeArea(edges: .bottom)
            .transition(.move(edge: .bottom))
            .animation(.spring(), value: showModal)
        }
    }
}


// MARK: - MODIFIED VIEW
struct EnhancedDirectionStepsModal: View {
    @Binding var showStepsModal: Bool
    @Binding var showSteps: Bool
    @State var destinationStore: Store
    @ObservedObject var pathfindingManager: PathfindingManager
    @Binding var showFloorChangeContent: Bool
    var onEndRoute: () -> Void
    @Binding var currentFloor: Floor
    @State private var pendingFloor: String? = nil
    @State private var navigationDirection: NavigationDirection? = nil

    enum NavigationDirection {
        case forward
        case backward
    }
    
    var body: some View {
        if showStepsModal {
            VStack(alignment: .trailing) {
                VStack(spacing: 16) {
                    // --- FLOOR CHANGE HEADER ---
                    if let step = pathfindingManager.getCurrentDirectionStep(),
                       step.fromFloor != nil && step.toFloor != nil, showFloorChangeContent {
                        
                        HStack {
                            Text("Change Floors")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                // Close the modal when in floor change mode
                                withAnimation {
                                    showFloorChangeContent = false
                                    pathfindingManager.moveToPreviousStep()
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        // Floor change content
                        FloorChangeContentView(step: step) {
                            // After confirming floor change, advance to next step
                            withAnimation {
                                showFloorChangeContent = false
                            }
                            pathfindingManager.moveToNextStep()
                            if let toFloor = step.toFloor {
                                currentFloor = toFloor
                            }
                        }
                        .padding(.horizontal, 16)
                        
                    }
                    // --- NORMAL TITLE + PROGRESS + STEPS ---
                    else {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("To \(destinationStore.name)")
                                        .font(.title3)
                                        .bold()
                                }
                                
                                Text("\(pathfindingManager.formatDistance(pathfindingManager.getRemainingDistance())) remaining – \(pathfindingManager.formatTime(pathfindingManager.getRemainingTime()))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 12) {
                                Button(action: { showSteps = true }) {
                                    Image(systemName: "chevron.up.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // If enhancedDirectionSteps empty -> loading card
                        if pathfindingManager.enhancedDirectionSteps.isEmpty {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Generating directions...")
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Color.blue) // replace with your customBlueColor constant
                            .cornerRadius(16)
                            .padding(.horizontal, 12)
                        } else {
                            // TabView needs a Binding<Int> for selection — create it manually
                            let selectionBinding = Binding<Int>(
                                get: { pathfindingManager.currentStepIndex },
                                set: { newIndex in
                                    pathfindingManager.moveToStep(newIndex)
                                }
                            )
                            
                            TabView(selection: selectionBinding) {
                                ForEach(Array(pathfindingManager.enhancedDirectionSteps.enumerated()), id: \.offset) { index, step in
                                    VStack(spacing: 8) {
                                        HStack {
                                            Image(systemName: step.icon)
                                                .foregroundColor(.white)
                                                .font(.system(size: 18, weight: .medium))
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(step.description)
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.leading)
                                                
                                                HStack {
                                                    Text("Step \(index + 1) of \(pathfindingManager.enhancedDirectionSteps.count)")
                                                        .foregroundColor(.white.opacity(0.8))
                                                        .font(.system(size: 12))
                                                    
                                                    Spacer()
                                                    
                                                    Text(pathfindingManager.formatDistance(step.distanceFromStart))
                                                        .foregroundColor(.white.opacity(0.9))
                                                        .font(.system(size: 11, weight: .medium))
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            if let tenantImage = getTenantImageForStep(step) {
                                                AsyncImage(url: tenantImage) { image in
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                } placeholder: {
                                                    Image(systemName: "building.2")
                                                        .foregroundColor(.white.opacity(0.7))
                                                }
                                                .frame(width: 32, height: 32)
                                                .clipShape(Circle())
                                                .padding(.horizontal, 8)
                                            } else {
                                                Image(systemName: "arrow.forward.circle")
                                                    .foregroundColor(.white.opacity(0.7))
                                                    .frame(width: 32, height: 32)
                                                    .padding(.horizontal, 8)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.blue) // replace with your customBlueColor
                                    .cornerRadius(16)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .tag(index) // important for TabView selection binding
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                            .frame(height: 90)
                            
                            // Navigation controls (no bindings required here)
                            HStack(spacing: 12) {
                                Button(action: {
                                    let oldFloor = currentFloor
                                        pathfindingManager.moveToPreviousStep()
                                        
                                        if let prevStep = pathfindingManager.getCurrentDirectionStep() {
                                            if let toFloor = prevStep.toFloor, toFloor != oldFloor {
                                                // Jika mundur dan step sebelumnya punya toFloor beda
                                                currentFloor = toFloor
                                                showFloorChangeContent = true
                                            } else if let fromFloor = prevStep.fromFloor, fromFloor != oldFloor {
                                                // Fallback: pakai fromFloor
                                                currentFloor = fromFloor
                                                showFloorChangeContent = true
                                            }
                                        }
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(pathfindingManager.currentStepIndex > 0 ? .blue : .gray)
                                }
                                .disabled(pathfindingManager.currentStepIndex <= 0)
                                
                                HStack(spacing: 6) {
                                    ForEach(0..<pathfindingManager.enhancedDirectionSteps.count, id: \.self) { idx in
                                        Circle()
                                            .fill(idx <= pathfindingManager.currentStepIndex ? Color.primary : Color.secondary.opacity(0.4))
                                            .frame(width: 8, height: 8)
                                            .animation(.easeInOut(duration: 0.2), value: pathfindingManager.currentStepIndex)
                                    }
                                }
                                
                                Button(action: {
                                    pathfindingManager.moveToNextStep()
                                }) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(pathfindingManager.currentStepIndex < pathfindingManager.enhancedDirectionSteps.count - 1 ? .blue : .gray)
                                }
                                .disabled(pathfindingManager.currentStepIndex >= pathfindingManager.enhancedDirectionSteps.count - 1)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                    } // end else normal
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16, corners: [.topLeft, .topRight])
            }
            .ignoresSafeArea(edges: .bottom)
            .transition(.move(edge: .bottom))
        }
    }
    
    private func getTenantImageForStep(_ step: EnhancedDirectionStep) -> URL? {
        // Extract tenant name from step description
        let description = step.description.lowercased()
        
        // Look for common patterns like "near [tenant]", "at [tenant]", etc.
        let words = description.components(separatedBy: " ")
        for (index, word) in words.enumerated() {
            if word == "near" || word == "at" {
                if index + 1 < words.count {
                    let tenantName = words[index + 1]
                    // Try to construct image URL
                    let config = APIConfiguration.shared
                    return URL(string: "\(config.baseURL)/images/\(tenantName).jpg")
                }
            }
        }
        
        return nil
    }
}


// NEW VIEW to handle the floor change UI inside the modal
struct FloorChangeContentView: View {
    let step: DirectionStep
    var onConfirm: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 32) {
            // Floor change message with proper styling
            if let fromFloor = step.fromFloor, let toFloor = step.toFloor {
                Text("Switch from \(fromFloor.displayName) to \(toFloor.displayName).")
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
            }
            
            // Confirm button
            Button(action: {
                onConfirm?()
            }) {
                Text("Confirm")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
            }
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 20)
    }
}

struct EnhancedDirectionStepsListView: View {
    @Binding var showStepsModal: Bool
    @Binding var showSteps: Bool
    @State var destinationStore: Store
    @ObservedObject var pathfindingManager: PathfindingManager
    var onEndRoute: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("To \(destinationStore.name)")
                        .font(.title3)
                        .bold()
                    Text("\(pathfindingManager.formatDistance(pathfindingManager.getRemainingDistance())) remaining – \(pathfindingManager.formatTime(pathfindingManager.getRemainingTime()))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Button(action: {
                    showSteps = false
                }) {
                    Image(systemName: "chevron.down")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Enhanced list with real-time tracking
            if pathfindingManager.enhancedDirectionSteps.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: customBlueColor))
                        .scaleEffect(1.2)
                    Text("Generating step-by-step directions...")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray6))
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(pathfindingManager.enhancedDirectionSteps.enumerated()), id: \.offset) { index, step in
                            HStack {
                                // Enhanced step indicator
                                ZStack {
                                    Circle()
                                        .fill(index <= pathfindingManager.currentStepIndex ? customBlueColor : Color.secondary.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                    
                                    if index < pathfindingManager.currentStepIndex {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .bold))
                                    } else if index == pathfindingManager.currentStepIndex {
                                        Image(systemName: "location.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .bold))
                                            .scaleEffect(1.2)
                                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pathfindingManager.currentStepIndex)
                                    } else {
                                        Image(systemName: step.icon)
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.description)
                                        .foregroundColor(index <= pathfindingManager.currentStepIndex ? .primary : .secondary)
                                        .font(.system(size: 16, weight: index == pathfindingManager.currentStepIndex ? .semibold : .regular))
                                        .lineLimit(nil)
                                        .multilineTextAlignment(.leading)
                                    
                                    HStack {
                                        if index == pathfindingManager.currentStepIndex {
                                            Text("Current step")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                                .fontWeight(.medium)
                                        } else if index < pathfindingManager.currentStepIndex {
                                            Text("Completed")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(pathfindingManager.formatDistance(step.distanceFromStart))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(pathfindingManager.formatTime(step.estimatedTimeFromStart))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.leading, 8)
                                
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(index == pathfindingManager.currentStepIndex ? Color.blue.opacity(0.1) : Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(index == pathfindingManager.currentStepIndex ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                            .onTapGesture {
                                pathfindingManager.moveToStep(index)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGray6))
            }
            
            // Enhanced end button
            Button(action: onEndRoute) {
                HStack {
                    Image(systemName: "stop.circle.fill")
                        .font(.title3)
                    Text("End Navigation")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: Color.red.opacity(0.3), radius: 4, x: 0, y: 2)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
