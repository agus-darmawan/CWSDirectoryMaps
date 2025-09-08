//
//  DirectionView.swift
//  CWSDirectoryMaps
//
//  Created by Daniel Fernando Herawan on 01/09/25.
//

import SwiftUI

struct DirectionView: View {
    
    @EnvironmentObject var dataManager: DataManager
    @StateObject var pathfindingManager = PathfindingManager() // make it a StateObject so it can publish changes
    
    let startLocation: Store
    @State var destinationStore: Store
    
    @State private var showDirectionsModal = true
    @State private var showStepsModal = false
    @State private var showSteps = false
    
    
    @State var pathWithLabels: [(point: CGPoint, label: String)] = []
    
    var body: some View {
        ZStack {
            
            VStack {
                if pathWithLabels.isEmpty {
                    // Show a loading indicator while path is being calculated
                    ProgressView("Calculating route...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Show the map only when path is ready
                    IntegratedMapView(
                        dataManager: dataManager,
                        pathWithLabels: $pathWithLabels,
                        pathfindingManager: pathfindingManager
                    )
                    .transition(.opacity)
                }
                Spacer()
                
                if showDirectionsModal {
                    DirectionsModal(
                        destinationStore: destinationStore,
                        startLocation: startLocation,
                        showModal: $showDirectionsModal
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
                        steps: pathfindingManager.directionSteps // Use real direction steps
                    )
                }
            }
            
            if showStepsModal && showSteps {
                DirectionStepsListView(
                    showStepsModal: $showStepsModal,
                    showSteps: $showSteps,
                    destinationStore: destinationStore,
                    steps: pathfindingManager.directionSteps // Use real direction steps
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
        }
        .onReceive(pathfindingManager.$pathWithLabels) { newPath in
            // Update local state whenever the manager publishes a new path
            self.pathWithLabels = newPath
        }
        .onReceive(pathfindingManager.$directionSteps) { newSteps in
            // Listen for direction steps updates
            print("Direction steps updated: \(newSteps.count) steps received")
            for (index, step) in newSteps.enumerated() {
                print("Step \(index + 1): \(step.description)")
            }
        }
    }
    
    private func runPathfinding() {
        guard let startLabel = startLocation.graphLabel,
              let endLabel = destinationStore.graphLabel else {
            print("Missing graph labels, cannot pathfind")
            return
        }
        
        let unifiedGraph = dataManager.unifiedGraph
        
        pathfindingManager.runPathfinding(
            startStore: startLocation,
            endStore: destinationStore,
            unifiedGraph: unifiedGraph
        )
    }
}



//#Preview {
//
//    let start = Store(
//        name: "Main Lobby",
//        category: .facilities,
//        imageName: "store_logo_placeholder",
//        subcategory: "Information Center",
//        description: "",
//        location: "Ground Floor, Central",
//        website: nil,
//        phone: nil,
//        hours: "06:00AM - 12:00AM",
//        detailImageName: "store_logo_placeholder"
//    )
//
//    let dest = Store(
//        name: "One Love Bespoke",
//        category: .shop,
//        imageName: "store_logo_placeholder",
//        subcategory: "Fashion, Watches & Jewelry",
//        description: "",
//        location: "Level 1, Unit 116",
//        website: nil,
//        phone: nil,
//        hours: "10:00AM - 10:00PM",
//        detailImageName: "store_logo_placeholder"
//    )
//
//    return DirectionView(startLocation: start, destinationStore: dest)
//}

