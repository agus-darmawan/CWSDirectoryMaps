//
//  ViewComponents.swift
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 02/09/25.
//

import SwiftUI

// MARK: - Reusable Search Bar View
struct SearchBarView: View {
    @Binding var text: String
    let placeholder: String
    let locations: [Location] // Changed from [String]
    @State private var isEditing = false
    
    var onLocationSelected: (Location) -> Void // Changed from (String) -> Void
    
    var field: Field
    @FocusState private var focusedField: Field?
    
    var body: some View {
        VStack(alignment: .leading) {
            // ... The HStack with the TextField is unchanged ...
            HStack {
                TextField(placeholder, text: $text)
                    .padding(7)
                    .padding(.horizontal, 25)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .autocorrectionDisabled(true)
                    .overlay(
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 8)
                        }
                    )
                    .focused($focusedField, equals: field)
                    .onTapGesture {
                        self.isEditing = true
                        self.focusedField = field
                    }
            }
            .padding(.horizontal, 10)
            
            if isEditing {
                // This filtering and list logic is updated
                List(locations.filter { $0.name.lowercased().contains(text.lowercased()) || text.isEmpty }, id: \.self) { location in
                    Text(location.name) // Display the location's name
                        .onTapGesture {
                            self.text = location.name // Set text field to the name
                            self.isEditing = false
                            self.onLocationSelected(location) // Pass the whole Location object back
                            self.focusedField = nil
                        }
                }
                .listStyle(PlainListStyle())
                .frame(maxHeight: 200)
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - View for a Single Direction Step
struct DirectionStepView: View {
    let step: DirectionStep
    
    var body: some View {
        HStack {
            Image(systemName: step.iconName)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40)
            
            Text(step.instruction)
                .foregroundColor(.white)
                .font(.body)
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.8))
        .cornerRadius(10)
    }
}
