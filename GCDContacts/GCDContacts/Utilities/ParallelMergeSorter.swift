//
//  ParallelMergeSorter.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 13/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 110
 
 */

import Foundation // [lines: 1]


class ParallelMergeSorter<T> { // [lines: 2]
    
    typealias Comparator = (T, T) -> Bool // [lines: 3]
    
    private let queue: DispatchQueue // [lines: 4]
    
    init(_ sortQueue: DispatchQueue? = nil) {
        self.queue = sortQueue ?? DispatchQueue(label: "ParallelMergeSorter.Queue", qos: .utility, attributes: .concurrent, target: .global(qos: .utility))
    } // [lines: 7]
    
    func sort(_ array: [T], parallelismLevel: Int = ProcessInfo.processInfo.processorCount, comparator: @escaping Comparator, completion: @escaping ([T]) -> Void) -> CancellationHandle {
        var array = array
        let chunksEqual = array.count % parallelismLevel == 0
        
        let limit = max(parallelismLevel, chunksEqual ? (array.count / parallelismLevel) : (array.count / (parallelismLevel - 1)))

        let completionWorkItem = DispatchWorkItem {
            completion(array)
        }
        
        var i = 0
        while i < array.count {
            let begin = i
            let remaining = array.count - i
            let end = remaining < limit ? (i + remaining - 1) : (i + limit - 1)
            
            queue.async { [weak self] in
                guard let self = self, !completionWorkItem.isCancelled else {
                    return
                }

                self.mergeSort(&array, begin: begin, end: end, comparator: comparator, isCancelled: completionWorkItem.isCancelled)
            }
            
            i += limit
        }
        
        queue.async(execute: DispatchWorkItem(flags: .barrier) { [weak self] in
            guard let self = self, !completionWorkItem.isCancelled else {
                return
            }
            
            var i = 0
            while i < array.count {
                guard !completionWorkItem.isCancelled else {
                    return
                }
                
                let middle = max(i - 1, 0)
                let remaining = array.count - i
                let end = remaining < limit ? (i + remaining - 1) : (i + limit - 1)
                
                self.merge(&array, begin: 0, middle: middle, end: end, comparator: comparator, isCancelled: completionWorkItem.isCancelled)
                
                i += limit
            }
            
            completionWorkItem.perform()
        })
        
        return CancellationHandle(completionWorkItem)
    } // [lines: 46]
    
    private func mergeSort(_ array: inout [T], begin: Int, end: Int, comparator: Comparator, isCancelled: @autoclosure () -> Bool) {
        guard begin < end, !isCancelled() else {
            return
        }
        
        let middle = (begin + end) / 2
        
        mergeSort(&array, begin: begin, end: middle, comparator: comparator, isCancelled: isCancelled())
        mergeSort(&array, begin: middle + 1, end: end, comparator: comparator, isCancelled: isCancelled())
        
        merge(&array, begin: begin, middle: middle, end: end, comparator: comparator, isCancelled: isCancelled())
    } // [lines: 55]
    
    private func merge(_ array: inout [T], begin: Int, middle: Int, end: Int, comparator: Comparator, isCancelled: @autoclosure () -> Bool) {
        var temp = Array<T?>.init(repeating: nil, count: end - begin + 1)
        
        var i = begin
        var j = middle + 1
        var k = 0
        
        while i <= middle && j <= end {
            guard !isCancelled() else {
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
            guard !isCancelled() else {
                return
            }
            
            temp[k] = array[i]
            i += 1
            k += 1
        }
        
        while j <= end {
            guard !isCancelled() else {
                return
            }
            
            temp[k] = array[j]
            j += 1
            k += 1
        }
        
        i = begin
        k = 0
        
        while i <= end {
            guard !isCancelled() else {
                return
            }
            
            array[i] = temp[k]!
            i += 1
            k += 1
        }
    } // [lines: 100]
    
    struct CancellationHandle {
        
        private let workItem: DispatchWorkItem
        
        fileprivate init(_ workItem: DispatchWorkItem) {
            self.workItem = workItem
        }
        
        func cancel() {
            workItem.cancel()
        }
    } // [lines: 109]
} // [lines: 110]
