//
//  DirectionView.swift
//  CWSDirectoryMaps
//
//  Created by Daniel Fernando Herawan on 01/09/25.
//

import SwiftUI

struct DirectionView: View {
    let startLocation: Store
    @State var destinationStore: Store
    
    @State private var showDirectionsModal = true
    @State private var showStepsModal = false
    @State private var showSteps = false
    
    var body: some View {
        ZStack {
            
            VStack {
                MapView()
                Spacer()
                
                if showDirectionsModal {
                    DirectionsModal(
                        destinationStore: destinationStore,
                        startLocation: startLocation,
                        showModal: $showDirectionsModal
                    ) {
                        showDirectionsModal = false
                        showStepsModal = true
                    }
                }
                
                if showStepsModal && !showSteps {
                    DirectionStepsModal(
                        showStepsModal: $showStepsModal,
                        showSteps: $showSteps,
                        destinationStore: destinationStore,
                        steps: dummySteps
                    )
                }
            }
            
            if showStepsModal && showSteps {
                DirectionStepsListView(
                    showStepsModal: $showStepsModal,
                    showSteps: $showSteps,
                    destinationStore: destinationStore,
                    steps: dummySteps
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .ignoresSafeArea(.all, edges: .bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

#Preview {

    let start = Store(
        name: "Main Lobby",
        category: .facilities,
        imageName: "store_logo_placeholder",
        subcategory: "Information Center",
        description: "",
        location: "Ground Floor, Central",
        website: nil,
        phone: nil,
        hours: "06:00AM - 12:00AM",
        detailImageName: "store_logo_placeholder"
    )
    
    let dest = Store(
        name: "One Love Bespoke",
        category: .shop,
        imageName: "store_logo_placeholder",
        subcategory: "Fashion, Watches & Jewelry",
        description: "",
        location: "Level 1, Unit 116",
        website: nil,
        phone: nil,
        hours: "10:00AM - 10:00PM",
        detailImageName: "store_logo_placeholder"
    )
    
    return DirectionView(startLocation: start, destinationStore: dest)
}
