//
//  ParallelMergeSorter.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 13/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 110
 
 TOTAL DEPENDENCY DEGREE: 179
 
 */

import Foundation // [lines: 1]


class ParallelMergeSorter<T> { // [lines: 2]
    
    typealias Comparator = (T, T) -> Bool // [lines: 3]
    
    private let queue: DispatchQueue // [lines: 4]
    
    // [dd: 1]
    init(_ sortQueue: DispatchQueue? = nil) {
        self.queue = sortQueue ?? DispatchQueue(label: "ParallelMergeSorter.Queue", qos: .utility, attributes: .concurrent, target: .global(qos: .utility)) // [rd: { init sortQueue } (1)]
    } // [lines: 7]
    
    // [dd: 38]
    func sort(_ array: [T], parallelismLevel: Int = ProcessInfo.processInfo.processorCount, comparator: @escaping Comparator, completion: @escaping ([T]) -> Void) -> CancellationHandle {
        var array = array // [rd: { init array } (1)]
        let chunksEqual = array.count % parallelismLevel == 0 // [rd: { (var array).count, init parallelismLevel } (2)]
        
        let limit = max(parallelismLevel, chunksEqual ? (array.count / parallelismLevel) : (array.count / (parallelismLevel - 1))) // [rd: { init parallelismLevel, let chunksEqual, (var.array).count } (3)]

        // closure: [dd: 2]
        let completionWorkItem = DispatchWorkItem { // [rd: { init completion, var array, self.merge(...) } (3)]
            completion(array) // [rd: { init completion, init array } (2)]
        }
        
        var i = 0
        while i < array.count { // [rd: { var i, i += limit, (var array).count } (3)]
            let begin = i // [rd: { var i, i += limit } (2)]
            let remaining = array.count - i // [rd: { (var array).count, var i, i += limit } (3)]
            let end = remaining < limit ? (i + remaining - 1) : (i + limit - 1) // [rd: { let remaining, let limit, var i, i += limit } (4)]
            
            // closure: [dd: 9]
            queue.async { [weak self] in // [rd: { init queue, let completionWorkItem, var array, self.mergeSort(&array, ...), let begin, let end, init comparator } (7)]
                guard let self = self, !completionWorkItem.isCancelled else { // [rd: { weak self, init completionWorkItem.isCancelled } (2)]
                    return
                }

                self.mergeSort(&array, begin: begin, end: end, comparator: comparator, isCancelled: completionWorkItem.isCancelled) // [rd: { let self, init array, self.mergeSort(&array, ...), init begin, init end, init comparator, init completionWorkItem.isCancelled } (7)]
            }
            
            i += limit // [rd: { var i, i += limit, let limit } (3)]
        }
        
        // closure: [dd: 27]
        queue.async(execute: DispatchWorkItem(flags: .barrier) { [weak self] in // [rd: { init queue, let completionWorkItem, var array, self.mergeSort(&array, ...), init comparator, let limit } (6)]
            guard let self = self, !completionWorkItem.isCancelled else { // [rd: { weak self, init completionWorkItem.isCancelled } (2)]
                return
            }
            
            var i = 0
            while i < array.count { // [rd: { var i, i += limit, (var array).count } (3)]
                guard !completionWorkItem.isCancelled else { // [rd: { init completionWorkItem.isCancelled } (1)]
                    return
                }
                
                let middle = max(i - 1, 0) // [rd: { var i, i += limit } (2)]
                let remaining = array.count - i // [rd: { (var array).count, var i, i += limit } (3)]
                let end = remaining < limit ? (i + remaining - 1) : (i + limit - 1) // [rd: { let remaining, let limit, var i, i += limit } (4)]
                
                self.merge(&array, begin: 0, middle: middle, end: end, comparator: comparator, isCancelled: completionWorkItem.isCancelled) // [rd: { let self, var array, self.mergeSort(&array, ...), self.merge(&array,...), middle, end, init comparator, init completionWorkItem.isCancelled } (8)]
                
                i += limit // [rd: { var i, i += limit, let limit } (3)]
            }
            
            completionWorkItem.perform() // [rd: { let completionWorkItem } (1)]
        })
        
        return CancellationHandle(completionWorkItem) // [rd: { let completionWorkItem } (1)]
    } // [lines: 46]
    
    // [dd: 21]
    private func mergeSort(_ array: inout [T], begin: Int, end: Int, comparator: Comparator, isCancelled: @autoclosure () -> Bool) {
        guard begin < end, !isCancelled() else { // [rd: { init begin, init end, init isCancelled } (3)]
            return
        }
        
        let middle = (begin + end) / 2 // [rd: { init begin, init end } (2)]
        
        mergeSort(&array, begin: begin, end: middle, comparator: comparator, isCancelled: isCancelled()) // [rd: { init array, init begin, let middle, init comparator, init isCancelled } (5)]
        mergeSort(&array, begin: middle + 1, end: end, comparator: comparator, isCancelled: isCancelled()) // [rd: { self.mergeSort(&array, ...), let middle, init end, init comparator, init isCancelled } (5)]
        
        merge(&array, begin: begin, middle: middle, end: end, comparator: comparator, isCancelled: isCancelled()) // [rd: { self.mergeSort(&array, ...), init begin, let middle, init end, init comparator, init isCancelled } (6)]
    } // [lines: 55]
    
    // [dd: 79]
    private func merge(_ array: inout [T], begin: Int, middle: Int, end: Int, comparator: Comparator, isCancelled: @autoclosure () -> Bool) {
        var temp = Array<T?>.init(repeating: nil, count: end - begin + 1) // [rd: { init end, init begin } (2)]
        
        var i = begin // [rd: { init begin } (1)]
        var j = middle + 1 // [rd: { init middle } (1)]
        var k = 0
        
        while i <= middle && j <= end { // [rd: { var i, init middle, var j, init end, i += 1, j += 1 } (6)]
            guard !isCancelled() else { // [rd: { init isCancelled } (1)]
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
            guard !isCancelled() else { // [rd: { init isCancelled } (1)]
                return
            }
            
            temp[k] = array[i] // [rd: { init array, var i, (i += 1) x 2 } (4)]
            i += 1 // [rd: { var i, (i += 1) x 2 } (3)]
            k += 1 // [rd: { var k, (k += 1) x 2 } (3)]
        }
        
        while j <= end { // [rd: { var j, init end, (j += 1) x 2 } (4)]
            guard !isCancelled() else { // [rd: { init isCancelled } (1)]
                return
            }
            
            temp[k] = array[j] // [rd: { init array, var j, (j += 1) x 2 } (4)]
            j += 1 // [rd: { var j, (j += 1) x 2 } (3)]
            k += 1 // [rd: { var k, (k += 1) x 3 } (4)]
        }
        
        i = begin // [rd: { init begin } (1)]
        k = 0
        
        while i <= end { // [rd: { i = begin, i += 1 } (2)]
            guard !isCancelled() else { // [rd: { init isCancelled } (1)]
                return
            }
            
            array[i] = temp[k]! // [rd: { var temp, (temp[k] = array[i]) x 2, (temp[k] = array[j]) x 2, k = 0, k += 1 } (7)]
            i += 1 // [rd: { i = begin, i += 1 } (2)]
            k += 1 // [rd: { k = 0, k += 1 } (2)]
        }
    } // [lines: 100]
    
    struct CancellationHandle {
        
        private let workItem: DispatchWorkItem
        
        // [dd: 1]
        fileprivate init(_ workItem: DispatchWorkItem) {
            self.workItem = workItem // [rd: { init workItem } (1)]
        }
        
        // [dd: 1]
        func cancel() {
            workItem.cancel() // [rd: { init workItem } (1)]
        }
    } // [lines: 109]
} // [lines: 110]
