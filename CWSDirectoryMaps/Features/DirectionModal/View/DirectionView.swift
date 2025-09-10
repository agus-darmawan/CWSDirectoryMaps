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
                    DirectionsModal(
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
                    DirectionStepsModal(
                        showStepsModal: $showStepsModal,
                        showSteps: $showSteps,
                        destinationStore: destinationStore,
                        pathfindingManager: pathfindingManager,
                        showFloorChangeContent: $showFloorChangeContent,
                        onEndRoute: {
                            showEndRouteAlert = true
                        }
                    )
                }
            }
            
            if showStepsModal && showSteps {
                DirectionStepsListView(
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
