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
                    MagnificationGesture() //pinch zoom
                        .onChanged { value in
                            scale = lastScale * value
                            offset = clampedOffset(offset, geo: geo)
                        }
                        .onEnded { _ in
                            lastScale = max(min(scale, 5.0), 1.0)
                            scale = lastScale
                            offset = clampedOffset(offset, geo: geo)
                            lastOffset = offset
                        }
                )
                .gesture(
                    DragGesture() //pan gesture
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
                .gesture(
                    DragGesture(minimumDistance: 0) //double tap zoom
                        .onEnded { value in
                            let now = Date()
                            if now.timeIntervalSince(lastTapTime) < 0.3 {
                                let location = value.location
                                withAnimation(.easeInOut) {
                                    if scale > 3 {
                                        //zoom out
                                        scale = 3
                                        lastScale = 3
                                        offset = .zero
                                        lastOffset = .zero
                                    } else if scale <= 3 {
                                        //zoom in
                                        let tapX = location.x - geo.size.width / 2
                                        let tapY = location.y - geo.size.height / 2
                                        
                                        scale = 5
                                        lastScale = 5
                                        
                                        offset = CGSize(
                                            width: -tapX * (scale - 1),
                                            height: -tapY * (scale - 1)
                                        )
                                        lastOffset = offset
                                    }
                                }
                            }
                            lastTapTime = now
                        }
                )
        }
    }
    //set boundary for panning (no white space)
    private func clampedOffset(_ proposed: CGSize, geo: GeometryProxy) -> CGSize {
        let screenWidth = geo.size.width
        let screenHeight = geo.size.height
        
        let contentAspect: CGFloat = 2000 / 2000
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
        let maxY = max((scaledHeight - screenHeight) / 2, 0)
        
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }
}

struct Maps: View {
    @State private var selectedFloor: String = "Ground Floor"
    
    let floors = [
        "4th Floor",
        "3rd Floor",
        "2nd Floor",
        "1st Floor",
        "Ground Floor",
        "Lower Ground"
    ]
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZoomableScrollView {
                Image(imageName(for: selectedFloor))
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Menu {
                ForEach(floors, id: \.self) { floor in
                    Button(action: {
                        selectedFloor = floor
                    }) {
                        Text(floor)
                    }
                }
            } label: {
                HStack {
                    Text(selectedFloor)
                        .font(.headline)
                    Image(systemName: "chevron.down")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.2), radius: 3)
                .foregroundColor(.primary)
            }
            .padding()
        }
    }
    
    private func imageName(for floor: String) -> String {
        switch floor {
        case "Lower Ground": return "floor-lower-ground"
        case "Ground Floor": return "floor-ground"
        case "1st Floor": return "floor-1"
        case "2nd Floor": return "floor-2"
        case "3rd Floor": return "floor-3"
        case "4th Floor": return "floor-4"
        default: return "floor-ground"
        }
    }
}

struct DirectionsModal: View {
    @Binding var showModal: Bool
    @State private var selectedMode: String = "walk"
    
    private var modeImageName: String {
        switch selectedMode {
        case "walk": return "figure.walk"
        case "wheelchair": return "figure.roll"
        default: return "figure.walk"
        }
    }
    
    var body: some View {
        if showModal {
            VStack {
                Spacer()
                
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
                            //from
                            HStack {
                                Image(systemName: "location.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Skechers")
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            
                            //to
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                Text("One Love Bespoke")
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
                                        print("Swap tapped")
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
                    }) {
                        Text("GO")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    .padding(.bottom, 24)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16, corners: [.topLeft, .topRight])
                //                .shadow(radius: 10)
            }
            .ignoresSafeArea(edges: .bottom)
            .transition(.move(edge: .bottom))
            .animation(.spring(), value: showModal)
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

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


#Preview {
    Maps()
    DirectionsModal(showModal: .constant(true))
}

