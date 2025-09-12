//
//  StoreRowView.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 28/08/25.
//

import SwiftUI

struct StoreRowView: View {
    let store: Store
    
    private let config = APIConfiguration.shared
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: config.baseURL + (store.imageName.hasPrefix("/") ? store.imageName : "/images/" + store.imageName))) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(store.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .background(Circle().fill(Color(.systemGray5)))
            
            Text(store.name)
                .font(.system(size: 17))
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
