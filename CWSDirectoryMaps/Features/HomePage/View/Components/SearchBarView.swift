//
//  SearchBarView.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 28/08/25.
//

import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    var isSearchFieldFocused: FocusState<Bool>.Binding
    var onClear: () -> Void
    var onCloseSearch: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                
                TextField("Search stores, exits, etc", text: $searchText)
                    .focused(isSearchFieldFocused)
                    .onTapGesture {
                        withAnimation {
                            isSearching = true
                        }
                    }
                    .accessibilityLabel("Search field")
                    .accessibilityHint("Tap to search for stores, restaurants, or facilities")
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""   // reset langsung di sini
                        onClear()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                    .accessibilityHint("Tap to clear search text")
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .contentShape(Rectangle())
            
            if isSearching {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        searchText = ""   // reset kalau Cancel ditekan
                        onCloseSearch()
                    }
                }) {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Cancel search")
                .accessibilityHint("Tap to close search and return to map view")
            }
        }
    }
}
