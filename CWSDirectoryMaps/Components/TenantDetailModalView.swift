//
//  TenantDetailModalView.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 28/08/25.
//

import SwiftUI

struct TenantDetailModal: View {
    let store: Store
    @Binding var isPresented: Bool
    @State private var showFullDescription = false
    
    private var customBlueColor: Color {
        Color(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 64/255, green: 156/255, blue: 255/255, alpha: 1.0)
            } else {
                return UIColor(red: 0/255, green: 46/255, blue: 127/255, alpha: 1.0)
            }
        })
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 36, height: 5)
                        .cornerRadius(3)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(store.subcategory)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            // Action for "From Here"
                        }) {
                            Text("From Here")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.systemGray))
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            // Action for "To Here"
                        }) {
                            Text("To Here")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(customBlueColor)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .background(Color(.systemBackground))
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Store image
                        AsyncImage(url: URL(string: store.detailImageName)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(store.detailImageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(showFullDescription ? store.description : String(store.description.prefix(150)) + (store.description.count > 150 ? "..." : ""))
                                .font(.body)
                                .lineLimit(showFullDescription ? nil : 3)
                            
                            if store.description.count > 150 {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showFullDescription.toggle()
                                    }
                                }) {
                                    Text(showFullDescription ? "Show Less" : "Show More")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(customBlueColor)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "storefront.fill")
                                    .frame(width: 24)
                                    .foregroundColor(.primary)
                                
                                Text(store.location)
                                    .font(.body)
                                
                                Spacer()
                            }
                            
                            if let website = store.website {
                                HStack {
                                    Image(systemName: "globe")
                                        .frame(width: 24)
                                        .foregroundColor(.primary)
                                    
                                    Button(action: {
                                        if let url = URL(string: website) {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        Text("Click here")
                                            .font(.body)
                                            .foregroundColor(customBlueColor)
                                            .underline()
                                    }
                                    
                                    Spacer()
                                }
                            }
                            
                            if let phone = store.phone {
                                HStack {
                                    Image(systemName: "phone.fill")
                                        .frame(width: 24)
                                        .foregroundColor(.primary)
                                    
                                    Button(action: {
                                        if let url = URL(string: "tel:\(phone)") {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        Text(phone)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            
                            HStack {
                                Image(systemName: "clock.fill")
                                    .frame(width: 24)
                                    .foregroundColor(.primary)
                                
                                Text(store.hours)
                                    .font(.body)
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}
