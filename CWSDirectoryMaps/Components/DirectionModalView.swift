//
//  DirectionModal.swift
//  CWSDirectoryMaps
//
//  Created by Daniel Fernando Herawan on 28/08/25.
//

import SwiftUI

// No changes needed for DirectionsModal, keeping it for context
struct DirectionsModal: View {
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
struct DirectionStepsModal: View {
    @Binding var showStepsModal: Bool
    @Binding var showSteps: Bool
    @State var destinationStore: Store
    @ObservedObject var pathfindingManager: PathfindingManager
    @Binding var showFloorChangeContent: Bool
    var onEndRoute: () -> Void

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
                        Text("Please use the stairs or elevator to change from \(step.fromFloor!.displayName) to \(step.toFloor!.displayName).")
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
                                    pathfindingManager.moveToPreviousStep()
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

// MARK: - Data Structures & Dummy Data (No Changes)
struct DirectionStep: Identifiable {
    let id = UUID()
    let point: CGPoint
    let icon: String
    var description: String
    let shopImage: String
    var isFloorChange: Bool = false
    var fromFloor: Floor?
    var toFloor: Floor?
}

//dummy data
let dummySteps: [DirectionStep] = [
    DirectionStep(point: .zero, icon: "arrow.up", description: "Go straight to Marks & Spencer", shopImage: "floor-1"),
    DirectionStep(point: .zero, icon: "arrow.turn.up.right", description: "Turn right at Starbucks", shopImage: "floor-1"),
    // This is now a floor change step
    DirectionStep(point: .zero, icon: "arrow.up.and.down.circle.fill", description: "Use escalator to Ground Floor", shopImage: "floor-1", isFloorChange: true, fromFloor: .lowerGround, toFloor: .ground),
    DirectionStep(point: .zero, icon: "arrow.turn.up.left", description: "Turn left after Zara", shopImage: "floor-1"),
    DirectionStep(point: .zero, icon: "mappin", description: "Arrive at destination", shopImage: "floor-1")
]


// No changes needed for DirectionStepsListView, keeping it for context
struct DirectionStepsListView: View {
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
