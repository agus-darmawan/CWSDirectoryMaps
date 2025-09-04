//
//  DirectionModal.swift
//  CWSDirectoryMaps
//
//  Created by Daniel Fernando Herawan on 28/08/25.
//

import SwiftUI

struct ZoomableScrollView<Content: View>: View {
    @ViewBuilder var content: Content
    
    @State private var scale: CGFloat = 3
    @State private var lastScale: CGFloat = 3
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    @State private var lastTapTime: Date = .distantPast
    
    var body: some View {
        GeometryReader { geo in
            content
                .scaleEffect(scale)
                .offset(offset)
                .onAppear {
                    offset = .zero
                    lastOffset = .zero
                }
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                                offset = clampedOffset(offset, geo: geo)
                            }
                            .onEnded { _ in
                                lastScale = max(min(scale, 5.0), 4.0)
                                scale = lastScale
                                offset = clampedOffset(offset, geo: geo)
                                lastOffset = offset
                            },
                        DragGesture()
                            .onChanged { value in
                                let newOffset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                                offset = clampedOffset(newOffset, geo: geo)
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                )
                .gesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.easeInOut) {
                                if scale > 3 {
                                    // zoom out
                                    scale = 3
                                    lastScale = 3
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    // zoom in
                                    scale = 5
                                    lastScale = 5
                                }
                            }
                        }
                )
        }
    }
    //set boundary for panning (no white space)
    private func clampedOffset(_ proposed: CGSize, geo: GeometryProxy) -> CGSize {
        let screenWidth = geo.size.width
        let screenHeight = geo.size.height
        
        let contentAspect: CGFloat = 1800 / 1200
        var contentWidth = screenWidth
        var contentHeight = screenHeight
        
        if contentAspect > screenWidth / screenHeight {
            contentHeight = screenWidth / contentAspect
        } else {
            contentWidth = screenHeight * contentAspect
        }
        
        let scaledWidth = contentWidth * scale
        let scaledHeight = contentHeight * scale
        
        let maxX = max((scaledWidth - screenWidth) / 2, 0)
        
        // Custom margin for bottom
        let bottomMargin: CGFloat = 0
        
        let maxY: CGFloat
        let minY: CGFloat
        if scaledHeight > screenHeight {
            maxY = (scaledHeight - screenHeight) / 2
            minY = -maxY + bottomMargin // tighter bottom
        } else {
            maxY = 0
            minY = 0
        }
        
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, minY), maxY)
        )
    }
}

struct DirectionsModal: View {
    @State var destinationStore: Store
    @State var startLocation: Store
    @Binding var showModal: Bool
    @Binding var showNavigationModal: Bool
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
                        
                        Button(action: {
                            showModal = false
                            showNavigationModal = true
                        }) {
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

struct DirectionStepsModal: View {
    @Binding var showStepsModal: Bool
    @Binding var showSteps: Bool
    
    let destinationStore: Store
    let steps: [DirectionStep]
    @State private var currentStepIndex: Int = 0
    
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
                    
                    //steps card
                    TabView(selection: $currentStepIndex) {
                        ForEach(Array(steps.enumerated()), id: \.1.id) { index, step in
                            HStack {
                                Image(systemName: step.icon)
                                    .foregroundColor(.white)
                                Text(step.description)
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                Image(step.shopImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                                    .padding(.horizontal, 8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(customBlueColor)
                            .cornerRadius(16)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(maxHeight: 60)
                    
                    //indicator card
                    HStack {
                        ForEach(0..<steps.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentStepIndex ? Color.primary : Color.secondary.opacity(0.4))
                                .frame(width: 8, height: 8)
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

struct DirectionStep: Identifiable {
    let id = UUID()
    let point: CGPoint
    let icon: String
    let description: String
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
    
    var body: some View {
        //        Spacer()
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


extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

let customBlueColor: Color = Color(uiColor: UIColor { traitCollection in
    if traitCollection.userInterfaceStyle == .dark {
        return UIColor(red: 64/255, green: 156/255, blue: 255/255, alpha: 1.0)
    } else {
        return UIColor(red: 0/255, green: 46/255, blue: 127/255, alpha: 1.0)
    }
})

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
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
//    MapView()
//    DirectionsModal(destinationStore: dest, startLocation: start, showModal: .constant(true))
//}
