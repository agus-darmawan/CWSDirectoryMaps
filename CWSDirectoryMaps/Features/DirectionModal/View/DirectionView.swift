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
            VStack {
                Spacer()
                
                if showDirectionsModal {
                    DirectionsModal(showModal: $showDirectionsModal) {
                        showStepsModal = true
                    }
                }
                
                if showStepsModal && !showSteps {
                    DirectionStepsModal(
                        showStepsModal: $showStepsModal,
                        showSteps: $showSteps,
                        destinationName: "One Love Bespoke",
                        steps: dummySteps
                    )
                }
            }
            if showStepsModal && showSteps {
                DirectionStepsListView(
                    showStepsModal: $showStepsModal,
                    showSteps: $showSteps,
                    destinationName: "One Love Bespoke",
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
    DirectionView()
}
