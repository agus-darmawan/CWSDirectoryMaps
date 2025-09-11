//
//  NetworkManager.swift
//  CWSDirectoryMaps
//
//  Created by Louis Fernando on 01/09/25.
//

import Foundation
import Combine

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private let session: URLSession
    private let config = APIConfiguration.shared
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = config.requestTimeout
        configuration.timeoutIntervalForResource = config.requestTimeout * 2
        self.session = URLSession(configuration: configuration)
    }
    
    func request<T: Codable>(
        endpoint: StoreEndpoint,
        responseType: T.Type
    ) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: config.baseURL + endpoint.path) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let body = endpoint.body {
            request.httpBody = body
        }
        
//        print("🌐 Making API call to: \(url.absoluteString)")
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.networkError
                    
                }
                
//                print("📡 Response status: \(httpResponse.statusCode)")
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw APIError.unauthorized
                case 404:
                    throw APIError.notFound
                case 400...499:
                    throw APIError.serverError(httpResponse.statusCode)
                case 500...599:
                    throw APIError.serverError(httpResponse.statusCode)
                default:
                    throw APIError.serverError(httpResponse.statusCode)
                }
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .retry(config.maxRetryAttempts)
            .mapError { error in
                print("❌ API Error: \(error)")
                if error is DecodingError {
                    return APIError.decodingError
                } else if let apiError = error as? APIError {
                    return apiError
                } else {
                    return APIError.networkError
                }
            }
            .eraseToAnyPublisher()
    }
}
