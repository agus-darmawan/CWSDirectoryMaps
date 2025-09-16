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
    
    @State var destinationStore: Store
    @State var startLocation: Store
    var onDismiss: (() -> Void)? = nil
    var onDismissNavigationModal: (() -> Void)? = nil
    var onDismissTenantModal: (() -> Void)? = nil
    
    @State private var showDirectionsModal = true
    @State private var showStepsModal = false
    @State private var showSteps = false
    @State private var selectedTravelMode: TravelMode = .escalator
    @State private var showFloorTransitionAlert = false
    @State private var transitionMessage = ""
    @State private var showEndRouteAlert = false
    @State private var currentFloor: Floor = .ground
    
    // New states for TextField UI
    @State private var startLocationText = ""
    @State private var destinationText = ""
    
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var viewModel: DirectoryViewModel
    
    @State var pathWithLabels: [(point: CGPoint, label: String)] = []
    
    // Computed property for reverse button state
    private var canReverse: Bool {
        return true // Always allow reverse for simplicity
    }
    
    var body: some View {
        ZStack {
            // Map content as background
            if pathWithLabels.isEmpty {
                ProgressView("Calculating route...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                IntegratedMapView(
                    dataManager: dataManager,
                    pathWithLabels: $pathWithLabels,
                    pathfindingManager: pathfindingManager,
                    currentFloor: $currentFloor,
                    viewModel: viewModel
                )
                .padding(.vertical, 100)
                .padding(.bottom, 140)
                .transition(.opacity)
            }
            
            VStack(spacing: 0) {
                // Top navigation header as overlay
                VStack(spacing: 0) {
                    // Navigation title
                    HStack {
                        Text("Navigation")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    
                    // Enhanced from-to section with TextField UI
                    HStack {
                        VStack(spacing: 0) {
                            // from
                            HStack {
                                Image(systemName: "location.circle.fill")
                                    .foregroundColor(.blue)
                                
                                TextField("Search starting location", text: $startLocationText)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .disabled(true) // Disabled since we're using preset locations
                                
                                Spacer()
                                
                                // No clear button needed since we're using preset locations
                            }
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            
                            // to
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                
                                TextField("Search destination", text: $destinationText)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .disabled(true) // Disabled since we're using preset locations
                                
                                Spacer()
                                
                                // No clear button needed since we're using preset locations
                            }
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                        }
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            Divider()
                                .frame(height: 1)
                                .padding(.leading, 36)
                                .padding(.trailing, 56)
                        )
                        if showDirectionsModal {
                                                    HStack {
                                                        Button(action: {
                                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                                // Swap the stores and update text fields
                                                                swap(&startLocation, &destinationStore)
                                                                startLocationText = startLocation.name
                                                                destinationText = destinationStore.name
                                                                
                                                                // Re-run pathfinding with swapped locations
                                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                                    pathfindingManager.runPathfinding(
                                                                        startStore: startLocation,
                                                                        endStore: destinationStore,
                                                                        unifiedGraph: dataManager.unifiedGraph
                                                                    )
                                                                }
                                                            }
                                                        }) {
                                                            Image(systemName: "arrow.up.arrow.down")
                                                                .font(.system(size: 14, weight: .medium))
                                                                .foregroundColor(.white)
                                                        }
                                                        .frame(width: 32, height: 32)
                                                        .background(canReverse ? customBlueColor : Color(.systemGray3))
                                                        .clipShape(Circle())
                                                        .disabled(!canReverse)
                                                    }
                                                }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                Spacer()
                
                // Bottom modals (only when needed)
                if showDirectionsModal {
                    EnhancedDirectionsModal(
                        destinationStore: destinationStore,
                        startLocation: startLocation,
                        showModal: $showDirectionsModal,
                        pathfindingManager: pathfindingManager,
                        selectedMode: $selectedTravelMode,
                        //                        onDismissAllModals: {
                        //                            onDismiss?()
                        //                            onDismissNavigationModal?()
                        //                            onDismissTenantModal?()
                        //                            dismiss()
                        //                        }
                        onEndRoute: {
                            showEndRouteAlert = true
                        },
                    ) {
                        showDirectionsModal = false
                        showStepsModal = true
                    }
                }
                
                if showStepsModal && !showSteps {
                    EnhancedDirectionStepsModal(
                        showStepsModal: $showStepsModal,
                        showSteps: $showSteps,
                        destinationStore: $destinationStore,
                        pathfindingManager: pathfindingManager,
                        onEndRoute: {
                            showEndRouteAlert = true
                        },
                        currentFloor: $currentFloor,
                        onDismissAllModals: {
                            onDismissNavigationModal?()
                            onDismissTenantModal?()
                            dismiss()
                            onDismiss?()
                        }
                    )
                }
            }
            
            if showStepsModal && showSteps {
                EnhancedDirectionStepsListView(
                    showStepsModal: $showStepsModal,
                    showSteps: $showSteps,
                    destinationStore: $destinationStore,
                    pathfindingManager: pathfindingManager,
                    onEndRoute: {
                        onDismiss?()
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
            // Initialize text fields with current store names
            startLocationText = startLocation.name
            destinationText = destinationStore.name
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
        // Floor transition alert
        .alert("Floor Change Required", isPresented: $showFloorTransitionAlert) {
            Button("OK") {
                // Move to next step after acknowledging floor change
                pathfindingManager.moveToNextStep()
            }
        } message: {
            Text(transitionMessage)
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
            showFloorTransitionAlert = true
            currentFloor = stepFloor
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
        onDismiss?()
        onDismissNavigationModal?()
        onDismissTenantModal?()
        dismiss()
    }
}

struct EnhancedDirectionsModal: View {
    @State var destinationStore: Store
    @State var startLocation: Store
    @Binding var showModal: Bool
    @ObservedObject var pathfindingManager: PathfindingManager
    @Binding var selectedMode: TravelMode
    @Environment(\.dismiss) private var dismiss
    //    var onDismissAllModals: (() -> Void)? = nil
    var onEndRoute: () -> Void
    
    var onGoTapped: (() -> Void)?
    
    var body: some View {
        if showModal {
            VStack(alignment: .trailing) {
                VStack(spacing: 24) {
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
                        
                        // Red End button
                        Button(action: {
                            onEndRoute()
                        }) {
                            Text("End")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.red)
                                .cornerRadius(16)
                        }
                        .padding(.trailing, 8)
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
                    
                    // Enhanced GO button
                    Button(action: {
                        //                        print("Go tapped - Starting navigation")
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
                .padding(.bottom, 32)
                .background(Color(.systemBackground))
                .cornerRadius(16, corners: [.topLeft, .topRight])
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
    @Binding var destinationStore: Store
    @ObservedObject var pathfindingManager: PathfindingManager
    var onEndRoute: () -> Void
    @Binding var currentFloor: Floor
    @Environment(\.dismiss) private var dismiss
    var onDismissAllModals: (() -> Void)? = nil
    
    var body: some View {
        if showStepsModal {
            VStack(alignment: .trailing) {
                VStack(spacing: 16) {
                    // --- MODIFICATION START ---
                    // Draggable handle and tappable area
                    VStack(spacing: 8) {
                        //                        RoundedRectangle(cornerRadius: 2.5)
                        //                            .fill(Color.secondary.opacity(0.6))
                        //                            .frame(width: 40, height: 5)
                        //                            .padding(.top, 8)
                        
                        // Title with real-time progress and buttons
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
                            
                            // Red End button
                            Button(action: {
                                onEndRoute()
                            }) {
                                Text("End")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.red)
                                    .cornerRadius(16)
                            }
                            .padding(.trailing, 8)
                            
                            // Chevron up button to show full steps
                            Button(action: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    showSteps = true
                                }
                            }) {
                                Image(systemName: "chevron.up")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle()) // Makes the whole area tappable
                    //                    .onTapGesture {
                    //                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    //                            showSteps = true
                    //                        }
                    //                    }
                    // --- MODIFICATION END ---
                    
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
                        .background(Color.blue)
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
                                    .onTapGesture {
                                        // Move to next step when tapping the step card
                                        pathfindingManager.moveToNextStep()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.blue)
                                .cornerRadius(16)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: 90)
                        
                        // Progress dots only
                        HStack(spacing: 6) {
                            ForEach(0..<pathfindingManager.enhancedDirectionSteps.count, id: \.self) { idx in
                                Circle()
                                    .fill(idx <= pathfindingManager.currentStepIndex ? Color.primary : Color.secondary.opacity(0.4))
                                    .frame(width: 8, height: 8)
                                    .animation(.easeInOut(duration: 0.2), value: pathfindingManager.currentStepIndex)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
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

struct EnhancedDirectionStepsListView: View {
    @Binding var showStepsModal: Bool
    @Binding var showSteps: Bool
    @Binding var destinationStore: Store
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
                .padding(.bottom, 32)
            }
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
