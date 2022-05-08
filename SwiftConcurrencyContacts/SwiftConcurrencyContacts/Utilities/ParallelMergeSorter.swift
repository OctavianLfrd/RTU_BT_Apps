//
//  ParallelMergeSorter.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 30/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 102
 
 TOTAL DEPENDENCY DEGREE: 173
 
 */

import Foundation // [lines: 1]


class ParallelMergeSorter<T> { // [lines: 2]
    
    typealias Comparator = (T, T) -> Bool // [lines: 3]
    
    // [dd: 3]
    func sort(_ array: [T], parallelismLevel: Int = ProcessInfo.processInfo.processorCount, comparator: @escaping Comparator) async throws -> [T] {
        // closure: [dd: 58]
        return try await withThrowingTaskGroup(of: (index: Int, array: [T]).self) { group in // [rd: { init array, init parallelismLevel, init comparator } (3)]
            let chunksEqual = array.count % parallelismLevel == 0 // [rd: { init array.count, init parallelismLevel } (2)]
            
            let limit = max(parallelismLevel, chunksEqual ? (array.count / parallelismLevel) : (array.count / (parallelismLevel - 1))) // [rd: { init parallelismLevel, let chunksEqual, init array.count } (3)]
            
            var i = 0
            var begin = 0
            while begin < array.count { // [rd: { var begin, begin += limit, init array.count } (3)]
                let remaining = array.count - begin // [rd: { init array.count, var begin, begin += limit } (3)]
                let end = remaining < limit ? (begin + remaining - 1) : (begin + limit - 1) // [rd: { let remaining, let limit, var begin, begin += limit } (4)]
                
                let subArrayIndex = i // [rd: { var i, i += 1 } (2)]
                let array = array[begin...end] // [rd: { init array, self.mergeSort(&array,...), var begin, begin += limit, let end } (5)]
                
                // closure: [dd: 9]
                group.addTask { [weak self] in // [rd: { init group, let array, init comparator, let subArrayIndex } (4)]
                    guard let self = self, !Task.isCancelled else { // [rd: { weak self, init Task.isCancelled } (2)]
                        throw CancellationError()
                    }
                    
                    var array = Array(array) // [rd: { init array } (1)]
                    self.mergeSort(&array, begin: 0, end: array.count - 1, comparator: comparator) // [rd: { let self, var array, (var array).count, init comparator } (4)]
                    return (subArrayIndex, array) // [rd: { init subArrayIndex, self.mergeSort(&array, ...) } (2)]
                }
                
                i += 1 // [rd: { var i, i += 1 } (2)]
                begin += limit // [rd: { var begin, begin += limit, let limit } (3)]
            }
            
            // closure: [dd: 4]
            var array: [T] = try await { // [rd: { init group, var i, i += 1 } (3)]
                var subArrayChunks = Array<[T]>.init(repeating: [], count: i) // [rd: { init i } (1)]
                
                for try await result in group { // [rd: { init group } (1)]
                    subArrayChunks[result.index] = result.array // [rd: { init result.array } (1)]
                }
                
                // closure: [dd: 2]
                return subArrayChunks.reduce(into: []) { partialResult, subArray in // [rd: { init subArrayChunks } (1)]
                    partialResult.append(contentsOf: subArray) // [rd: { init partialResult, init subArray } (2)]
                }
            } ()
            
            i = 0
            while i < array.count { // [rd: { i = 0, i += limit, init array.count } (3)]
                try Task.checkCancellation() // [rd: { init Task } (1)]
                
                let middle = max(i - 1, 0) // [rd: { i = 0, i += limit } (2)]
                let remaining = array.count - i // [rd: { init array.count, i = 0, i += limit } (3)]
                let end = remaining < limit ? (i + remaining - 1) : (i + limit - 1) // [rd: { let remaining, let limit, i = 0, i += limit } (4)]
                
                self.merge(&array, begin: 0, middle: middle, end: end, comparator: comparator) // [rd: { var array, self.merge(&array,...), let middle, let end, init comparator } (5)]
                
                i += limit // [rd: { i = 0, i += limit, let limit } (3)]
            }
            
            try Task.checkCancellation() // [rd: { init Task } (1)]
            
            return array // [rd: { var array, self.merge(&array) } (2)]
        }
    } // [lines: 47]
    
    // [dd: 18]
    private func mergeSort(_ array: inout [T], begin: Int, end: Int, comparator: Comparator) {
        guard begin < end, !Task.isCancelled else { // [rd: { init begin, init end, init Task.isCancelled } (3)]
            return
        }
        
        let middle = (begin + end) / 2 // [rd: { init begin, init end } (2)]
        
        mergeSort(&array, begin: begin, end: middle, comparator: comparator) // [rd: { init array, init begin, let middle, init comparator } (4)]
        mergeSort(&array, begin: middle + 1, end: end, comparator: comparator) // [rd: { self.mergeSort(&array, ...), let middle, init end, init comparator } (4)]
        
        merge(&array, begin: begin, middle: middle, end: end, comparator: comparator) // [rd: { self.mergeSort(&array, ...), init begin, let middle, init end, init comparator } (5)]
    } // [lines: 56]
    
    // [dd: 79]
    private func merge(_ array: inout [T], begin: Int, middle: Int, end: Int, comparator: Comparator) {
        var temp = Array<T?>.init(repeating: nil, count: end - begin + 1) // [rd: { init end, init begin } (2)]
        
        var i = begin // [rd: { init begin } (1)]
        var j = middle + 1 // [rd: { init middle } (1)]
        var k = 0
        
        while i <= middle && j <= end { // [rd: { var i, init middle, var j, init end, i += 1, j += 1 } (6)]
            guard !Task.isCancelled else { // [rd: { init Task.isCancelled } (1)]
                return
            }
            
            if comparator(array[i], array[j]) { // [rd: { init comparator, init array, var i, var j, i += 1, j += 1 } (6)]
                temp[k] = array[i] // [rd: { var array, var k, var i, k += 1, i += 1 } (5)]
                i += 1 // [rd: { var i, i += 1 } (2)]
            } else {
                temp[k] = array[j]  // [rd: { var array, var k, var j, k += 1, j += 1 } (5)]
                j += 1 // [rd: { var j, j += 1 } (2)]
            }
            k += 1 // [rd: { var k, k += 1 } (2)]
        }
        
        while i <= middle { // [rd: { var i, init middle, (i += 1) x 2 } (4)]
            guard !Task.isCancelled else { // [rd: { init Task.isCancelled } (1)]
                return
            }
            
            temp[k] = array[i] // [rd: { init array, var i, (i += 1) x 2 } (4)]
            i += 1 // [rd: { var i, (i += 1) x 2 } (3)]
            k += 1 // [rd: { var k, (k += 1) x 2 } (3)]
        }
        
        while j <= end { // [rd: { var j, init end, (j += 1) x 2 } (4)]
            guard !Task.isCancelled else { // [rd: { init Task.isCancelled } (1)]
                return
            }
            
            temp[k] = array[j] // [rd: { init array, var j, (j += 1) x 2 } (4)]
            j += 1 // [rd: { var j, (j += 1) x 2 } (3)]
            k += 1 // [rd: { var k, (k += 1) x 3 } (4)]
        }
        
        i = begin // [rd: { init begin } (1)]
        k = 0
        
        while i <= end { // [rd: { i = begin, i += 1 } (2)]
            guard !Task.isCancelled else { // [rd: { init Task.isCancelled } (1)]
                return
            }
            
            array[i] = temp[k]! // [rd: { var temp, (temp[k] = array[i]) x 2, (temp[k] = array[j]) x 2, k = 0, k += 1 } (7)]
            i += 1 // [rd: { i = begin, i += 1 } (2)]
            k += 1 // [rd: { k = 0, k += 1 } (2)]
        }
    }
} // [lines: 102]
