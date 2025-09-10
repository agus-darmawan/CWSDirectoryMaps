//
//  DirectionModal.swift
//  CWSDirectoryMaps
//
//  Created by Daniel Fernando Herawan on 28/08/25.
//

import SwiftUI

//struct ZoomableScrollView<Content: View>: View {
//    @ViewBuilder var content: Content
//    
//    @State private var scale: CGFloat = 3
//    @State private var lastScale: CGFloat = 3
//    @State private var offset: CGSize = .zero
//    @State private var lastOffset: CGSize = .zero
//    
//    @State private var lastTapTime: Date = .distantPast
//    
//    var body: some View {
//        GeometryReader { geo in
//            content
//                .scaleEffect(scale)
//                .offset(offset)
//                .onAppear {
//                    offset = .zero
//                    lastOffset = .zero
//                }
//                .gesture(
//                    SimultaneousGesture(
//                        MagnificationGesture()
//                            .onChanged { value in
//                                scale = lastScale * value
//                                offset = clampedOffset(offset, geo: geo)
//                            }
//                            .onEnded { _ in
//                                lastScale = max(min(scale, 5.0), 4.0)
//                                scale = lastScale
//                                offset = clampedOffset(offset, geo: geo)
//                                lastOffset = offset
//                            },
//                        DragGesture()
//                            .onChanged { value in
//                                let newOffset = CGSize(
//                                    width: lastOffset.width + value.translation.width,
//                                    height: lastOffset.height + value.translation.height
//                                )
//                                offset = clampedOffset(newOffset, geo: geo)
//                            }
//                            .onEnded { _ in
//                                lastOffset = offset
//                            }
//                    )
//                )
//                .gesture(
//                    TapGesture(count: 2)
//                        .onEnded {
//                            withAnimation(.easeInOut) {
//                                if scale > 3 {
//                                    // zoom out
//                                    scale = 3
//                                    lastScale = 3
//                                    offset = .zero
//                                    lastOffset = .zero
//                                } else {
//                                    // zoom in
//                                    scale = 5
//                                    lastScale = 5
//                                }
//                            }
//                        }
//                )
//        }
//    }
//    //set boundary for panning (no white space)
//    private func clampedOffset(_ proposed: CGSize, geo: GeometryProxy) -> CGSize {
//        let screenWidth = geo.size.width
//        let screenHeight = geo.size.height
//        
//        let contentAspect: CGFloat = 1800 / 1200
//        var contentWidth = screenWidth
//        var contentHeight = screenHeight
//        
//        if contentAspect > screenWidth / screenHeight {
//            contentHeight = screenWidth / contentAspect
//        } else {
//            contentWidth = screenHeight * contentAspect
//        }
//        
//        let scaledWidth = contentWidth * scale
//        let scaledHeight = contentHeight * scale
//        
//        let maxX = max((scaledWidth - screenWidth) / 2, 0)
//        
//        // Custom margin for bottom
//        let bottomMargin: CGFloat = 0
//        
//        let maxY: CGFloat
//        let minY: CGFloat
//        if scaledHeight > screenHeight {
//            maxY = (scaledHeight - screenHeight) / 2
//            minY = -maxY + bottomMargin // tighter bottom
//        } else {
//            maxY = 0
//            minY = 0
//        }
//        
//        return CGSize(
//            width: min(max(proposed.width, -maxX), maxX),
//            height: min(max(proposed.height, minY), maxY)
//        )
//    }
//}
//
//private var customBlueColor: Color {
//    Color(uiColor: UIColor { traitCollection in
//        if traitCollection.userInterfaceStyle == .dark {
//            return UIColor(red: 64/255, green: 156/255, blue: 255/255, alpha: 1.0)
//        } else {
//            return UIColor(red: 0/255, green: 46/255, blue: 127/255, alpha: 1.0)
//        }
//    })
//}

struct DirectionsModal: View {
    @State var destinationStore: Store
    @State var startLocation: Store
    @Binding var showModal: Bool
    @State private var selectedMode: String = "walk"
    
    // Enhanced properties for navigation tracking
    @State private var totalDistance: Double = 0.0
    @State private var estimatedTime: Double = 0.0
    
    var onGoTapped: (() -> Void)?
    
    private var modeImageName: String {
        switch selectedMode {
        case "walk": return "figure.walk"
        case "wheelchair": return "figure.roll"
        default: return "figure.walk"
        }
    }
    
    // Calculate distance and time based on mode
    private func calculateNavigationMetrics() {
        // Default distance calculation (you can replace with actual path calculation)
        let defaultDistance: Double = 200.0
        totalDistance = defaultDistance
        
        // Calculate estimated time based on mode
        switch selectedMode {
        case "walk":
            // Average walking speed: 5 km/h = 1.39 m/s
            estimatedTime = totalDistance / 1.39
        case "wheelchair":
            // Average wheelchair speed: 3 km/h = 0.83 m/s
            estimatedTime = totalDistance / 0.83
        default:
            estimatedTime = totalDistance / 1.39
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 1 {
            return "< 1 min"
        }
        return "\(minutes) min\(minutes > 1 ? "s" : "")"
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1fkm", meters / 1000)
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
                            Text("\(formatDistance(totalDistance)) – \(formatTime(estimatedTime))")
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
                            calculateNavigationMetrics()
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
                            calculateNavigationMetrics()
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
                                        calculateNavigationMetrics()
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
            .onAppear {
                calculateNavigationMetrics()
            }
        }
    }
}

struct DirectionStepsModal: View {
    @Binding var showStepsModal: Bool
    @Binding var showSteps: Bool
    
    let destinationStore: Store
    let steps: [DirectionStep]
    @State private var currentStepIndex: Int = 0
    
    // Enhanced navigation tracking
    @State private var totalDistance: Double = 200.0
    @State private var estimatedTime: Double = 240.0 // 4 minutes in seconds
    @State private var currentDistance: Double = 0.0
    @State private var remainingTime: Double = 240.0
    
    private func updateNavigationProgress() {
        guard !steps.isEmpty else { return }
        
        // Calculate progress based on current step
        let progress = Double(currentStepIndex) / Double(steps.count)
        currentDistance = totalDistance * progress
        remainingTime = estimatedTime * (1.0 - progress)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 1 {
            return "< 1 min"
        }
        return "\(minutes) min\(minutes > 1 ? "s" : "")"
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }
    
    var body: some View {
        if showStepsModal{
            VStack (alignment: .trailing) {
                
                VStack(spacing: 16) {
                    //title
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("To  \(destinationStore.name)")
                                    .font(.title3)
                                    .bold()
                            }
                            Text("\(formatDistance(totalDistance - currentDistance)) remaining – \(formatTime(remainingTime))")
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
                    
                    //steps card
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
                        .onChange(of: currentStepIndex) { _, _ in
                            updateNavigationProgress()
                        }
                        
                        //indicator card with navigation progress
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                ForEach(0..<steps.count, id: \.self) { index in
                                    Circle()
                                        .fill(index <= currentStepIndex ? Color.primary : Color.secondary.opacity(0.4))
                                        .frame(width: 8, height: 8)
                                        .animation(.easeInOut(duration: 0.2), value: currentStepIndex)
                                }
                            }
                            
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.3))
                                        .frame(height: 4)
                                        .cornerRadius(2)
                                    
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: geometry.size.width * (Double(currentStepIndex) / Double(max(1, steps.count - 1))), height: 4)
                                        .cornerRadius(2)
                                        .animation(.easeInOut(duration: 0.3), value: currentStepIndex)
                                }
                            }
                            .frame(height: 4)
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
            .onAppear {
                updateNavigationProgress()
            }
        }
    }
}

struct DirectionStep: Identifiable {
    let id = UUID()
    let point: CGPoint
    let icon: String
    var description: String
    let shopImage: String
}

//dummy data
let dummySteps: [DirectionStep] = [
    DirectionStep(point: .zero, icon: "arrow.up", description: "Go straight to Marks & Spencer", shopImage: "floor-1"),
    DirectionStep(point: .zero, icon: "arrow.turn.up.right", description: "Turn right at Starbucks", shopImage: "floor-1"),
    DirectionStep(point: .zero, icon: "arrow.turn.up.left", description: "Turn left after Zara", shopImage: "floor-1"),
    DirectionStep(point: .zero, icon: "mappin", description: "Arrive at destination", shopImage: "floor-1")
]

struct DirectionStepsListView: View {
    @Binding var showStepsModal: Bool
    @Binding var showSteps: Bool
    
    let destinationStore: Store
    let steps: [DirectionStep]
    
    // Enhanced navigation tracking
    @State private var currentStepIndex: Int = 0
    @State private var totalDistance: Double = 200.0
    @State private var estimatedTime: Double = 240.0
    @State private var currentDistance: Double = 0.0
    @State private var remainingTime: Double = 240.0
    
    private func updateNavigationProgress() {
        guard !steps.isEmpty else { return }
        
        let progress = Double(currentStepIndex) / Double(steps.count)
        currentDistance = totalDistance * progress
        remainingTime = estimatedTime * (1.0 - progress)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 1 {
            return "< 1 min"
        }
        return "\(minutes) min\(minutes > 1 ? "s" : "")"
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("To \(destinationStore.name)")
                        .font(.title3)
                        .bold()
                    Text("\(formatDistance(totalDistance - currentDistance)) remaining – \(formatTime(remainingTime))")
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
            
            // List steps with enhanced navigation
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
                        ForEach(Array(steps.enumerated()), id: \.1.id) { index, step in
                            HStack {
                                // Enhanced step indicator
                                ZStack {
                                    Circle()
                                        .fill(index <= currentStepIndex ? customBlueColor : Color.secondary.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                    
                                    if index < currentStepIndex {
                                        // Completed step
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .bold))
                                    } else if index == currentStepIndex {
                                        // Current step
                                        Image(systemName: "location.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .bold))
                                    } else {
                                        // Future step
                                        Image(systemName: step.icon)
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.description)
                                        .foregroundColor(index <= currentStepIndex ? .primary : .secondary)
                                        .font(.system(size: 16, weight: index == currentStepIndex ? .semibold : .regular))
                                        .lineLimit(nil)
                                        .multilineTextAlignment(.leading)
                                    
                                    if index == currentStepIndex {
                                        Text("Current step")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            .fontWeight(.medium)
                                    } else if index < currentStepIndex {
                                        Text("Completed")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(.leading, 8)
                                
                                Spacer()
                                
                                // Step navigation buttons
                                if index == currentStepIndex {
                                    HStack(spacing: 8) {
                                        if currentStepIndex > 0 {
                                            Button(action: {
                                                currentStepIndex -= 1
                                                updateNavigationProgress()
                                            }) {
                                                Image(systemName: "chevron.left")
                                                    .foregroundColor(.blue)
                                                    .frame(width: 30, height: 30)
                                                    .background(Color.blue.opacity(0.1))
                                                    .clipShape(Circle())
                                            }
                                        }
                                        
                                        if currentStepIndex < steps.count - 1 {
                                            Button(action: {
                                                currentStepIndex += 1
                                                updateNavigationProgress()
                                            }) {
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.blue)
                                                    .frame(width: 30, height: 30)
                                                    .background(Color.blue.opacity(0.1))
                                                    .clipShape(Circle())
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(index == currentStepIndex ? Color.blue.opacity(0.1) : Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(index == currentStepIndex ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                            .onTapGesture {
                                currentStepIndex = index
                                updateNavigationProgress()
                            }
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
        .onAppear {
            updateNavigationProgress()
        }
    }
}

//
//extension View {
//    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
//        clipShape(RoundedCorner(radius: radius, corners: corners))
//    }
//}
//
//let customBlueColor: Color = Color(uiColor: UIColor { traitCollection in
//    if traitCollection.userInterfaceStyle == .dark {
//        return UIColor(red: 64/255, green: 156/255, blue: 255/255, alpha: 1.0)
//    } else {
//        return UIColor(red: 0/255, green: 46/255, blue: 127/255, alpha: 1.0)
//    }
//})

//struct RoundedCorner: Shape {
//    var radius: CGFloat
//    var corners: UIRectCorner
//    
//    func path(in rect: CGRect) -> Path {
//        let path = UIBezierPath(
//            roundedRect: rect,
//            byRoundingCorners: corners,
//            cornerRadii: CGSize(width: radius, height: radius)
//        )
//        return Path(path.cgPath)
//    }
//}

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
//    MapView()
//    DirectionsModal(destinationStore: dest, startLocation: start, showModal: .constant(true))
//}
