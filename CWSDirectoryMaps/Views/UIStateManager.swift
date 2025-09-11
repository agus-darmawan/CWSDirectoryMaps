//
//  UIStateManager.swift
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 02/09/25.
//

import SwiftUI

// MARK: - UI State Manager
class UIStateManager: ObservableObject {
    // Search and navigation state
    @Published var startLabel: String = "braun_buffel-5"
    @Published var endLabel: String = "coach-1"
    @Published var startFloor: Floor = .ground
    @Published var endFloor: Floor = .ground
    
    // MARK: - Public Methods
    func updateStartLocation(_ location: Location) {
        startLabel = location.name
        startFloor = location.floor
    }
    
    func updateEndLocation(_ location: Location) {
        endLabel = location.name
        endFloor = location.floor
    }
    
    func clearSearchFields() {
        startLabel = ""
        endLabel = ""
    }
    
    func hasValidSearchInputs() -> Bool {
        return !startLabel.isEmpty && !endLabel.isEmpty
    }
}
