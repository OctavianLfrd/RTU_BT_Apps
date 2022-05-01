//
//  ParallelMergeSorter.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 30/04/2022.
//

import Foundation


class ParallelMergeSorter<T> {
    
    typealias Comparator = (T, T) -> Bool
    
    func sort(_ array: [T], parallelismLevel: Int = ProcessInfo.processInfo.processorCount, comparator: @escaping Comparator) async throws -> [T] {
        return try await withThrowingTaskGroup(of: (index: Int, array: [T]).self) { group in
            let chunksEqual = array.count % parallelismLevel == 0
            
            let limit = max(parallelismLevel, chunksEqual ? (array.count / parallelismLevel) : (array.count / (parallelismLevel - 1)))
            
            var i = 0
            var begin = 0
            while begin < array.count {
                let remaining = array.count - begin
                let end = remaining < limit ? (begin + remaining - 1) : (begin + limit - 1)
                
                let subArrayIndex = i
                let array = array[begin...end]
                
                group.addTask { [weak self] in
                    guard let self = self, !Task.isCancelled else {
                        throw CancellationError()
                    }
                    
                    var array = Array(array)
                    self.mergeSort(&array, begin: 0, end: array.count - 1, comparator: comparator)
                    return (subArrayIndex, array)
                }
                
                i += 1
                begin += limit
            }
            
            var array: [T] = try await {
                var subArrayChunks = Array<[T]>.init(repeating: [], count: i)
                
                for try await result in group {
                    subArrayChunks[result.index] = result.array
                }
                
                return subArrayChunks.reduce(into: []) { partialResult, subArray in
                    partialResult.append(contentsOf: subArray)
                }
            } ()
            
            i = 0
            while i < array.count {
                try Task.checkCancellation()
                
                let middle = max(i - 1, 0)
                let remaining = array.count - i
                let end = remaining < limit ? (i + remaining - 1) : (i + limit - 1)
                
                self.merge(&array, begin: 0, middle: middle, end: end, comparator: comparator)
                
                i += limit
            }
            
            try Task.checkCancellation()
            
            return array
        }
    }
    
    private func mergeSort(_ array: inout [T], begin: Int, end: Int, comparator: Comparator) {
        guard begin < end, !Task.isCancelled else {
            return
        }
        
        let middle = (begin + end) / 2
        
        mergeSort(&array, begin: begin, end: middle, comparator: comparator)
        mergeSort(&array, begin: middle + 1, end: end, comparator: comparator)
        
        merge(&array, begin: begin, middle: middle, end: end, comparator: comparator)
    }
    
    private func merge(_ array: inout [T], begin: Int, middle: Int, end: Int, comparator: Comparator) {
        var temp = Array<T?>.init(repeating: nil, count: end - begin + 1)
        
        var i = begin
        var j = middle + 1
        var k = 0
        
        while i <= middle && j <= end {
            guard !Task.isCancelled else {
                return
            }
            
            if comparator(array[i], array[j]) {
                temp[k] = array[i]
                i += 1
            } else {
                temp[k] = array[j]
                j += 1
            }
            k += 1
        }
        
        while i <= middle {
            guard !Task.isCancelled else {
                return
            }
            
            temp[k] = array[i]
            i += 1
            k += 1
        }
        
        while j <= end {
            guard !Task.isCancelled else {
                return
            }
            
            temp[k] = array[j]
            j += 1
            k += 1
        }
        
        i = begin
        k = 0
        
        while i <= end {
            guard !Task.isCancelled else {
                return
            }
            
            array[i] = temp[k]!
            i += 1
            k += 1
        }
    }
}
