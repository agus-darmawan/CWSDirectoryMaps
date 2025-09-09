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
    @State private var selectedMode: String = "walk"
    var onGoTapped: (() -> Void)?
    
    private var modeImageName: String {
        switch selectedMode {
        case "walk": return "figure.walk"
        case "wheelchair": return "figure.roll"
        default: return "figure.walk"
        }
    }
    
    var body: some View {
        if showModal {
            VStack (alignment: .trailing){
                VStack(spacing: 16) {
                    //title
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Directions")
                                    .font(.title3)
                                    .bold()
                                Image(systemName: modeImageName)
                            }
                            Text("200m – 4 mins")
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
                    
                    //mode
                    HStack {
                        Button {
                            selectedMode = "walk"
                        } label: {
                            Image(systemName: "figure.walk")
                                .frame(width: 55, height: 37)
                                .background(
                                    selectedMode == "walk" ? Color.blue : Color.gray.opacity(0.2)
                                )
                                .foregroundColor(
                                    selectedMode == "walk" ? .white : .primary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Button {
                            selectedMode = "wheelchair"
                        } label: {
                            Image(systemName: "figure.roll")
                                .frame(width: 55, height: 37)
                                .background(
                                    selectedMode == "wheelchair" ? Color.blue : Color.gray.opacity(0.2)
                                )
                                .foregroundColor(
                                    selectedMode == "wheelchair" ? .white : .primary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    
                    // from-to
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
                        
                        //divider
                        Divider()
                            .frame(height: 1)
                            .padding(.leading, 36)
                            .padding(.trailing, 56)
                            .overlay(
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        swap(&startLocation, &destinationStore)
                                    }) {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.trailing, 16)
                                }
                            )
                    }
                    
                    //go button
                    Button(action: {
                        print("Go tapped")
                        showModal = false
                        onGoTapped?()
                    }) {
                        Text("GO")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16, corners: [.topLeft, .topRight])
                .frame(height: 300)
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
    
    let destinationStore: Store
    let steps: [DirectionStep]
    @State private var currentStepIndex: Int = 0
    
    // NEW STATE to control which content to show
    @State private var showFloorChangeContent = false
    
    var body: some View {
        if showStepsModal{
            VStack (alignment: .trailing) {
                
                VStack(spacing: 16) {
                    // Check if current step is floor change and show different title
                    if showFloorChangeContent {
                        // Floor Change Title
                        HStack {
                            Text("Change Floors")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                // Close the modal when in floor change mode
                                showStepsModal = false
                            }) {
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 4)
                    } else {
                        // Regular title for normal steps
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("To  \(destinationStore.name)")
                                        .font(.title3)
                                        .bold()
                                }
                                Text("200m – 4 mins")
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
                    }
                    
                    // Check if current step is floor change and show appropriate content
                    if showFloorChangeContent && currentStepIndex < steps.count {
                        // Floor Change Content
                        FloorChangeContentView(
                            step: steps[currentStepIndex],
                            onConfirm: {
                                // Move to next step after confirming floor change
                                if currentStepIndex < steps.count - 1 {
                                    currentStepIndex += 1
                                }
                            }
                        )
                    } else {
                        // Regular Steps Content
                        if steps.isEmpty {
                            // Show loading state when no steps available
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
                            TabView(selection: $currentStepIndex) {
                                ForEach(Array(steps.enumerated()), id: \.1.id) { index, step in
                                    // Regular step view
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
                                            
                                            Text("Step \(index + 1) of \(steps.count)")
                                                .foregroundColor(.white.opacity(0.8))
                                                .font(.system(size: 12))
                                        }
                                        
                                        Spacer()
                                        
                                        Image(step.shopImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                            .padding(.horizontal, 8)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(customBlueColor)
                                    .cornerRadius(16)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .tag(index)
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                            .frame(height: 80)
                            .onChange(of: currentStepIndex) { _, newIndex in
                                // Update showFloorChangeContent when step changes
                                if newIndex < steps.count {
                                    // Use withAnimation for a smoother transition
                                    withAnimation(.easeInOut) {
                                        showFloorChangeContent = steps[newIndex].isFloorChange
                                    }
                                }
                            }
                            .onAppear {
                                // Set initial state
                                if !steps.isEmpty {
                                    showFloorChangeContent = steps[currentStepIndex].isFloorChange
                                }
                            }
                            
                            //indicator card without navigation buttons
                            HStack {
                                Spacer()
                                
                                HStack(spacing: 6) {
                                    ForEach(0..<steps.count, id: \.self) { index in
                                        Circle()
                                            .fill(index == currentStepIndex ? Color.primary : Color.secondary.opacity(0.4))
                                            .frame(width: 8, height: 8)
                                            .animation(.easeInOut(duration: 0.2), value: currentStepIndex)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
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

// MARK: - Data Structures & Dummy Data (No Changes)
struct DirectionStep: Identifiable {
    let id = UUID()
    let point: CGPoint
    let icon: String
    let description: String
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
    
    let destinationStore: Store
    let steps: [DirectionStep]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("To \(destinationStore.name)")
                        .font(.title3)
                        .bold()
                    Text("200m – 4 mins")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                //navigate DirectionStepsModal
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
            
            // List steps
            if steps.isEmpty {
                // Show loading state when no steps available
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
                        ForEach(steps) { step in
                            HStack {
                                Image(systemName: step.icon)
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                
                                Text(step.description)
                                    .foregroundColor(.white)
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                                    .padding(.leading, 4)
                                
                                Spacer()
                                
                                Image(step.shopImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            }
                            .padding()
                            .background(customBlueColor)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGray6))
            }
            
            // End button
            Button(action: {
                showStepsModal = false
            }) {
                Text("End Route")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}


// MARK: - Preview
#Preview {
    
    let start = Store(
        id: "start-lobby",
        name: "Main Lobby",
        category: .facilities,
        imageName: "store_logo_placeholder",
        subcategory: "Information Center",
        description: "",
        location: "Ground Floor, Central",
        website: nil,
        phone: nil,
        hours: "06:00AM - 12:00AM",
        detailImageName: "store_logo_placeholder"
    )
    
    let dest = Store(
        id: "dest-onelove",
        name: "One Love Bespoke",
        category: .shop,
        imageName: "store_logo_placeholder",
        subcategory: "Fashion, Watches & Jewelry",
        description: "",
        location: "Level 1, Unit 116",
        website: nil,
        phone: nil,
        hours: "10:00AM - 10:00PM",
        detailImageName: "store_logo_placeholder"
    )
    
    DirectionsModal(destinationStore: dest, startLocation: start, showModal: .constant(true))
}
