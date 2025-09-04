//
//  MapView.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 28/08/25.
//

import SwiftUI

struct MapView: View {
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
                    .accessibilityLabel("Mall map for \(selectedFloor)")
                    .accessibilityHint("Pinch to zoom, drag to pan around the map")
            }
            .clipped()
            .accessibilityElement(children: .combine)
            
            Menu {
                ForEach(floors, id: \.self) { floor in
                    Button(action: {
                        selectedFloor = floor
                    }) {
                        HStack {
                            Text(floor)
                            if floor == selectedFloor {
                                Image(systemName: "checkmark")
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .accessibilityLabel(floor)
                    .accessibilityAddTraits(floor == selectedFloor ? .isSelected : [])
                }
            } label: {
                HStack {
                    Text(selectedFloor)
                        .font(.headline)
                    Image(systemName: "chevron.down")
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.2), radius: 3)
                .foregroundColor(.primary)
            }
            .accessibilityLabel("Floor selector")
            .accessibilityHint("Currently showing \(selectedFloor). Tap to select a different floor")
            .accessibilityValue(selectedFloor)
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

#Preview {
    MapView()
}
