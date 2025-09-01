////
////  ContentView.swift
////  CWSDirectoryMaps
////
////  Created by Steven Gonawan on 27/08/25.
////
//
//
////
////  ContentView.swift
////  SwiftUI Map
////
////  Created by Steven Gonawan on 25/08/25.
////
//
//import SwiftUI
//
//// MARK: - ContentView
//struct ContentView: View {
//    @State private var graph: Graph? = nil
//    
//    var body: some View {
//        GeometryReader { geo in
//            ZStack {
//                if let graph = graph {
//                    let bounds = graphBounds(graph)
//                    let scale = fittingScale(bounds: bounds, in: geo.size)
//                    let offset = fittingOffset(bounds: bounds, in: geo.size, scale: scale)
//                    
//                    ZStack {
//                        // Draw edges
//                        ForEach(graph.edges) { edge in
//                            if let from = graph.nodes.first(where: { $0.id == edge.source }),
//                               let to   = graph.nodes.first(where: { $0.id == edge.target }) {
//                                
//                                Path { path in
//                                    path.move(to: CGPoint(x: from.x, y: from.y))
//                                    path.addLine(to: CGPoint(x: to.x, y: to.y))
//                                }
//                                .stroke(Color.white.opacity(0.6), lineWidth: 5)
//                            }
//                        }
//                        
//                        // Draw nodes
//                        ForEach(graph.nodes) { node in
//                            Circle()
//                                .fill(color(for: node))
//                                .frame(width: 6, height: 6)
//                                .position(x: node.x, y: node.y)
//                        }
//                    }
//                    .scaleEffect(scale, anchor: .topLeading)
//                    .offset(offset)
//                } else {
//                    Text("Loading graph...")
//                        .padding()
//                }
//            }
//            .background(Color.black.opacity(0.9).ignoresSafeArea())
//            .onAppear {
//                self.graph = loadGraph()
//            }
//        }
//    }
//    
//    // MARK: - Coloring
//    private func color(for node: Node) -> Color {
//        switch node.type {
//        case "ellipse-center": return .blue
//        case "ellipse-point": return .green
//        case "path-point": return .orange
//        default: return .red
//        }
//    }
//    
//    // MARK: - Helpers
//    private func graphBounds(_ graph: Graph) -> CGRect {
//        let xs = graph.nodes.map { $0.x }
//        let ys = graph.nodes.map { $0.y }
//        guard let minX = xs.min(), let maxX = xs.max(),
//              let minY = ys.min(), let maxY = ys.max() else {
//            return .zero
//        }
//        return CGRect(x: minX, y: minY,
//                      width: maxX - minX,
//                      height: maxY - minY)
//    }
//    
//    private func fittingScale(bounds: CGRect, in size: CGSize) -> CGFloat {
//        guard bounds.width > 0, bounds.height > 0 else { return 1 }
//        let scaleX = size.width / bounds.width
//        let scaleY = size.height / bounds.height
//        return min(scaleX, scaleY) * 0.95 // padding
//    }
//    
//    private func fittingOffset(bounds: CGRect, in size: CGSize, scale: CGFloat) -> CGSize {
//        let graphWidth = bounds.width * scale
//        let graphHeight = bounds.height * scale
//        let x = (size.width - graphWidth) / 2 - bounds.minX * scale
//        let y = (size.height - graphHeight) / 2 - bounds.minY * scale
//        return CGSize(width: x, height: y)
//    }
//}
//
//// MARK: - Preview
//#Preview {
//    ContentView()
//}
