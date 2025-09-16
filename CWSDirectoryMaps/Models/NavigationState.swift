//
//  NavigationState.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 28/08/25.
//

import Foundation

enum NavigationMode {
    case fromHere
    case toHere
}

struct NavigationState {
    var startLocation: Store?
    var endLocation: Store?
    var mode: NavigationMode?
    
    mutating func setLocation(_ store: Store, for mode: NavigationMode) {
        switch mode {
        case .fromHere:
            startLocation = store
        case .toHere:
            endLocation = store
        }
    }
    
    mutating func reverseLocations() {
        let temp = startLocation
        startLocation = endLocation
        endLocation = temp
    }
    
    mutating func clear() {
        startLocation = nil
        endLocation = nil
        mode = nil
    }
}
