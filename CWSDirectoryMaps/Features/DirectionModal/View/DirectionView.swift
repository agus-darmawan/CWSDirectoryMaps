//
//  DirectionView.swift
//  CWSDirectoryMaps
//
//  Created by Daniel Fernando Herawan on 01/09/25.
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
                    // Show the map with enhanced navigation tracking
                    IntegratedMapView(
                        dataManager: dataManager,
                        pathWithLabels: $pathWithLabels,
                        pathfindingManager: pathfindingManager
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
                        pathfindingManager: pathfindingManager
                    )
                }
            }
            
            if showStepsModal && showSteps {
                EnhancedDirectionStepsListView(
                    showStepsModal: $showStepsModal,
                    showSteps: $showSteps,
                    destinationStore: destinationStore,
                    pathfindingManager: pathfindingManager
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
        .onReceive(pathfindingManager.$enhancedDirectionSteps) { newSteps in
            // Listen for enhanced direction steps updates
            print("Enhanced direction steps updated: \(newSteps.count) steps received")
            for (index, step) in newSteps.enumerated() {
                print("Enhanced Step \(index + 1): \(step.description) - Distance: \(pathfindingManager.formatDistance(step.distanceFromStart)) - Time: \(pathfindingManager.formatTime(step.estimatedTimeFromStart))")
            }
        }
        .onChange(of: selectedTravelMode) { _, newMode in
            pathfindingManager.updateTravelMode(newMode)
        }
    }
    
    private func runPathfinding() {
        guard let startLabel = startLocation.graphLabel,
              let endLabel = destinationStore.graphLabel else {
            print("Missing graph labels, cannot pathfind")
            return
        }
        
        let unifiedGraph = dataManager.unifiedGraph
        
        // Set the travel mode first
        pathfindingManager.updateTravelMode(selectedTravelMode)
        
        pathfindingManager.runPathfinding(
            startStore: startLocation,
            endStore: destinationStore,
            unifiedGraph: unifiedGraph
        )
    }
}

// MARK: - Enhanced Directions Modal
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

// MARK: - Enhanced Direction Steps Modal
struct EnhancedDirectionStepsModal: View {
    @Binding var showStepsModal: Bool
    @Binding var showSteps: Bool
    @State var destinationStore: Store
    @ObservedObject var pathfindingManager: PathfindingManager
    
    var body: some View {
        if showStepsModal {
            VStack(alignment: .trailing) {
                VStack(spacing: 16) {
                    // Title with real-time progress
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
                        
                        Button(action: { showSteps = true }) {
                            Image(systemName: "chevron.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 12)
                    }
                    
                    // Enhanced steps card
                    if pathfindingManager.enhancedDirectionSteps.isEmpty {
                        // Show loading state
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
                        .background(customBlueColor)
                        .cornerRadius(16)
                        .padding(.horizontal, 12)
                    } else {
                        TabView(selection: $pathfindingManager.currentStepIndex) {
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
                                        
                                        Image(step.shopImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                            .padding(.horizontal, 8)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(customBlueColor)
                                .cornerRadius(16)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: 90)
                        
                            // Navigation controls with circles only
                        HStack(spacing: 12) {
                            Button(action: {
                                pathfindingManager.moveToPreviousStep()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(pathfindingManager.currentStepIndex > 0 ? .blue : .gray)
                            }
                            .disabled(pathfindingManager.currentStepIndex <= 0)
                            
                            HStack(spacing: 6) {
                                ForEach(0..<pathfindingManager.enhancedDirectionSteps.count, id: \.self) { index in
                                    Circle()
                                        .fill(index <= pathfindingManager.currentStepIndex ? Color.primary : Color.secondary.opacity(0.4))
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
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16, corners: [.topLeft, .topRight])
            }
            .ignoresSafeArea(edges: .bottom)
            .transition(.move(edge: .bottom))
        }
    }
}

// MARK: - Enhanced Direction Steps List View
struct EnhancedDirectionStepsListView: View {
    @Binding var showStepsModal: Bool
    @Binding var showSteps: Bool
    @State var destinationStore: Store
    @ObservedObject var pathfindingManager: PathfindingManager
    
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
                                        // Completed step
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .bold))
                                    } else if index == pathfindingManager.currentStepIndex {
                                        // Current step with pulsing effect
                                        Image(systemName: "location.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .bold))
                                            .scaleEffect(1.2)
                                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pathfindingManager.currentStepIndex)
                                    } else {
                                        // Future step
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
            Button(action: {
                showStepsModal = false
            }) {
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

let customBlueColor: Color = Color(uiColor: UIColor { traitCollection in
    if traitCollection.userInterfaceStyle == .dark {
        return UIColor(red: 64/255, green: 156/255, blue: 255/255, alpha: 1.0)
    } else {
        return UIColor(red: 0/255, green: 46/255, blue: 127/255, alpha: 1.0)
    }
})
