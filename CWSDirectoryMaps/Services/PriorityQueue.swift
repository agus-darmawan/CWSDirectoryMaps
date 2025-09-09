//
//  PriorityQueue.swift
//  CWSDirectoryMaps
//
//  Created by Steven Gonawan on 02/09/25.
//

import Foundation

struct PriorityQueue {
    private var heap = [(fScore: Double, label: String)]()
    
    var isEmpty: Bool { heap.isEmpty }
    
    mutating func enqueue(_ element: (fScore: Double, label: String)) {
        heap.append(element)
        siftUp(heap.count - 1)
    }

    mutating func dequeue() -> (fScore: Double, label: String)? {
        guard !heap.isEmpty else { return nil }
        heap.swapAt(0, heap.count - 1)
        let element = heap.removeLast()
        if !heap.isEmpty { siftDown(0) }
        return element
    }
    
    private mutating func siftUp(_ index: Int) {
        var childIndex = index
        var parentIndex = (childIndex - 1) / 2
        while childIndex > 0 && heap[childIndex].fScore < heap[parentIndex].fScore {
            heap.swapAt(childIndex, parentIndex)
            childIndex = parentIndex
            parentIndex = (childIndex - 1) / 2
        }
    }
    
    private mutating func siftDown(_ index: Int) {
        var parentIndex = index
        while true {
            let leftChild = 2 * parentIndex + 1
            let rightChild = 2 * parentIndex + 2
            var smallestIndex = parentIndex
            
            if leftChild < heap.count && heap[leftChild].fScore < heap[smallestIndex].fScore {
                smallestIndex = leftChild
            }
            if rightChild < heap.count && heap[rightChild].fScore < heap[smallestIndex].fScore {
                smallestIndex = rightChild
            }
            
            if smallestIndex != parentIndex {
                heap.swapAt(parentIndex, smallestIndex)
                parentIndex = smallestIndex
            } else {
                return
            }
        }
    }
}
