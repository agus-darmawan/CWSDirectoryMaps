//
//  ContentView.swift
//  CWSDirectoryMaps
//
//  Created by Darmawan on 25/08/25.
//

import SwiftUI

struct ContentView: View {
    // 1. Create a single instance of DataManager for the entire app.
    @StateObject private var dataManager = DataManager()
    
    var body: some View {
        HomePageView()
            // 3. Make the dataManager available to HomePageView and all its child views.
            .environmentObject(dataManager)
            // 2. When the view appears, start pre-loading all the floor data.
            .task {
                print("--- Preloading all floor data on app launch ---")
                await dataManager.preloadAllFloorData()
                
            }
    }
}

#Preview {
    ContentView()
}
