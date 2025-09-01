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
                
                TextField("Search stores, exits, etc", text: $searchText)
                    .focused(isSearchFieldFocused)
                    .onTapGesture {
                        withAnimation {
                            isSearching = true
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            if isSearching {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onCloseSearch()
                    }
                }) {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.blue)
                }
            }
        }
    }
}
