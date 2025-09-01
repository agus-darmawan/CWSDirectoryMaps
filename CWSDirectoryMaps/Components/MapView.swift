//
//  MapView.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 28/08/25.
//

import SwiftUI

struct MapDirectoryView: View {
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        Image("map_placeholder")
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = value
                    }
            )
    }
}

struct MapNavigationView: View {
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
        case "Lower Ground": return "map_lowerground_floor_2d"
        case "Ground Floor": return "map_ground_floor_2d"
        case "1st Floor": return "map_1st_floor_2d"
        case "2nd Floor": return "map_2nd_floor_2d"
        case "3rd Floor": return "map_3rd_floor_2d"
        case "4th Floor": return "map_4th_floor_2d"
        default: return "map_ground_floor_2d"
        }
    }
}

#Preview {
    MapNavigationView()
}