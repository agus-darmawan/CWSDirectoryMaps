//
//  ContentView.swift
//  CWSDirectoryMaps
//
//  Created by Darmawan on 25/08/25.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var dataManager = DataManager()
    
    var body: some View {
        HomePageView()
            .environmentObject(dataManager)
            .task {
                print("--- Preloading all floor data on app launch ---")
                await dataManager.preloadAllFloorData()
                
            }
    }
}

#Preview {
    ContentView()
}
