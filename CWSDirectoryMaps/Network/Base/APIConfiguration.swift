//
//  APIConfiguration.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 01/09/25.
//

import Foundation

struct APIConfiguration {
    static let shared = APIConfiguration()
    
    private init() {}
    
    var baseURL: String {
        return "https://cwmaps-api.agus-darmawan.com"
    }
    
    var requestTimeout: TimeInterval = 30.0
    
    var maxRetryAttempts: Int = 3
    var retryDelay: TimeInterval = 1.0
    
    var useAPI: Bool {
        return true
    }
}
