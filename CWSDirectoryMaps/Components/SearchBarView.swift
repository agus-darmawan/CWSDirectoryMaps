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
    
    var body: some View {
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
    }
}
