//
//  GraphLoader.swift
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 02/09/25.
//

import Foundation
import CoreGraphics

func loadGraph() -> Graph? {
    guard let url = Bundle.main.url(forResource: "pathfinding_graph", withExtension: "json") else {
        print("Error: pathfinding_graph.json not found in bundle.")
        return nil
    }
    
    do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(Graph.self, from: data)
    } catch {
        print("Error loading or decoding graph: \(error)")
        return nil
    }
}
