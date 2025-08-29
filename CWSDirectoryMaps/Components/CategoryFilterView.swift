//
//  CategoryFilterView.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 28/08/25.
//

import SwiftUI

struct CategoryFilterView: View {
    let categories: [StoreCategory]
    @Binding var selectedCategory: StoreCategory?
    var onSelect: (StoreCategory) -> Void
    
    var body: some View {
        if let selectedCat = selectedCategory {
            HStack(spacing: 16) {
                HStack {
                    Text(selectedCat.rawValue)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                    
                    Button(action: {
                        onSelect(selectedCat)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 14)
                }
                .background(Color.blue)
                .cornerRadius(10)
                
                Spacer()
            }
            .padding(.horizontal)
        } else {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach([StoreCategory.shop, .fnb, .play, .others], id: \.self) { category in
                        Button(action: {
                            onSelect(category)
                        }) {
                            Text(category.rawValue)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.systemGray))
                                .cornerRadius(10)
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    ForEach([StoreCategory.facilities, .entrances], id: \.self) { category in
                        Button(action: {
                            onSelect(category)
                        }) {
                            Text(category.rawValue)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.systemGray))
                                .cornerRadius(10)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
