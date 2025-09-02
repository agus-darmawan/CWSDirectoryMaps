//
//  DirectionView.swift
//  CWSDirectoryMaps
//
//  Created by Daniel Fernando Herawan on 01/09/25.
//

import SwiftUI

struct DirectionView: View {
    @State private var showDirectionsModal = true
    @State private var showStepsModal = false
    @State private var showSteps = false
    
    var body: some View {
        ZStack {
            MapView()
                .ignoresSafeArea()
                
            VStack {
                Spacer()
                
                if showDirectionsModal {
                    DirectionsModal(showModal: $showDirectionsModal) {
                        showStepsModal = true
                    }
                }
                if showStepsModal {
                    if showSteps {
                        DirectionStepsListView(
                            showStepsModal: $showStepsModal,
                            showSteps: $showSteps,
                            destinationName: "One Love Bespoke",
                            steps: dummySteps
                        )
                    } else {
                        DirectionStepsModal(
                            showStepsModal: $showStepsModal,
                            showSteps: $showSteps,
                            destinationName: "One Love Bespoke",
                            steps: dummySteps
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    DirectionView()
}
