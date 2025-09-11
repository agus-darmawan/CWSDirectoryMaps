//
//  MapViewManager.swift
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 02/09/25.
//

import SwiftUI
import CoreGraphics

// MARK: - Map View Manager
class MapViewManager: ObservableObject {
    // Map interaction state
    @Published var scale: CGFloat = 1.0
    @Published var lastScale: CGFloat = 1.0
    @Published var offset: CGSize = .zero
    @Published var lastOffset: CGSize = .zero
    @Published var selectedFloor: Floor = .ground
    
    // Current display data
    @Published var currentGraph: Graph? = nil
    @Published var currentLocations: [String] = []
    
    // MARK: - Public Methods
    func switchToFloor(_ floor: Floor, floorData: [Floor: FloorData]) {
        print("switchToFloor called with: \(floor.rawValue)")
        
        guard let data = floorData[floor] else {
            print("No preloaded data for \(floor.rawValue)")
            return
        }
        
//        print("Switching to \(floor.rawValue)")
        
        // Reset view state for new floor
        resetViewState()
        
        // Set new floor data
        currentGraph = data.graph
        currentLocations = data.locations
        selectedFloor = floor
        
        print("Successfully switched to \(floor.rawValue)")
        print("Available locations: \(currentLocations.count)")
        
    }
    
    func resetViewState() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
    
    func updateScale(_ newScale: CGFloat) {
        scale = newScale
    }
    
    func updateOffset(_ newOffset: CGSize) {
        offset = newOffset
        lastOffset = newOffset
    }
    
    func updateLastScale() {
        lastScale = 1.0
    }
    
    // MARK: - Map Utility Functions
    func color(for node: Node) -> Color {
        return .white
    }
    
    func graphBounds(_ graph: Graph) -> CGRect {
        let xs = graph.nodes.map { $0.x }
        let ys = graph.nodes.map { $0.y }
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return .zero
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    func fittingScale(bounds: CGRect, in size: CGSize) -> CGFloat {
        guard bounds.width > 0, bounds.height > 0 else { return 1 }
        let scaleX = size.width / bounds.width
        let scaleY = size.height / bounds.height
        return min(scaleX, scaleY)
    }
    
    func fittingOffset(bounds: CGRect, in size: CGSize, scale: CGFloat) -> CGSize {
        let graphWidth = bounds.width * scale
        let graphHeight = bounds.height * scale
        let x = (size.width - graphWidth) / 2 - bounds.minX * scale
        let y = (size.height - graphHeight) / 2 - bounds.minY * scale
        return CGSize(width: x, height: y)
    }
}
