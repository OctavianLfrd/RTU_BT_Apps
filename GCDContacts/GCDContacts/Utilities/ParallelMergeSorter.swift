//
//  ParallelMergeSorter.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 13/04/2022.
//

import Foundation


class ParallelMergeSorter<T> {
    
    typealias Comparator = (T, T) -> Bool
    
    private let queue: DispatchQueue
    
    init(_ queue: DispatchQueue?) {
        self.queue = queue ?? DispatchQueue(label: "ParallelMergeSorter.Queue", qos: .utility, attributes: .concurrent, target: .global(qos: .utility))
    }
    
    func sort(_ array: [T], parallelismLevel: Int = ProcessInfo.processInfo.processorCount, comparator: @escaping Comparator, completion: @escaping ([T]) -> Void) -> CancellationHandle {
        var array = array
        let chunksEqual = array.count % parallelismLevel == 0
        
        let limit = max(parallelismLevel, chunksEqual ? (array.count / parallelismLevel) : (array.count / (parallelismLevel - 1)))

        var workItems = [DispatchWorkItem]()
        
        var i = 0
        while i < array.count {
            let begin = i
            let remaining = array.count - i
            let end = remaining < limit ? (i + remaining - 1) : (i + limit - 1)
            
            var workItem: DispatchWorkItem!
            workItem = DispatchWorkItem { [weak self] in
                guard let self = self, !workItem.isCancelled else {
                    return
                }
                
                self.mergeSort(&array, begin: begin, end: end, comparator: comparator, workItem: workItem)
            }
            
            workItems.append(workItem)
            
            queue.async(execute: workItem)
            
            i += limit
        }
        
        var barrierWorkItem: DispatchWorkItem!
        barrierWorkItem = DispatchWorkItem(flags: .barrier) { [weak self] in
            guard let self = self, !barrierWorkItem.isCancelled else {
                return
            }
            
            var i = 0
            while i < array.count {
                guard !barrierWorkItem.isCancelled else {
                    return
                }
                
                let middle = max(i - 1, 0)
                let remaining = array.count - i
                let end = remaining < limit ? (i + remaining - 1) : (i + limit - 1)
                
                self.merge(&array, begin: 0, middle: middle, end: end, comparator: comparator, workItem: barrierWorkItem)
                
                i += limit
            }
            
            guard !barrierWorkItem.isCancelled else {
                return
            }
            
            completion(array)
        }
        
        workItems.append(barrierWorkItem)
        
        queue.async(execute: barrierWorkItem)
        
        return CancellationHandle(workItems)
    }
    
    private func mergeSort(_ array: inout [T], begin: Int, end: Int, comparator: Comparator, workItem: DispatchWorkItem) {
        guard begin < end, !workItem.isCancelled else {
            return
        }
        
        let middle = (begin + end) / 2
        
        mergeSort(&array, begin: begin, end: middle, comparator: comparator, workItem: workItem)
        mergeSort(&array, begin: middle + 1, end: end, comparator: comparator, workItem: workItem)
        
        merge(&array, begin: begin, middle: middle, end: end, comparator: comparator, workItem: workItem)
    }
    
    private func merge(_ array: inout [T], begin: Int, middle: Int, end: Int, comparator: Comparator, workItem: DispatchWorkItem) {
        var temp = Array<T?>.init(repeating: nil, count: end - begin + 1)
        
        var i = begin
        var j = middle + 1
        var k = 0
        
        while i <= middle && j <= end {
            guard !workItem.isCancelled else {
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
            guard !workItem.isCancelled else {
                return
            }
            
            temp[k] = array[i]
            i += 1
            k += 1
        }
        
        while j <= end {
            guard !workItem.isCancelled else {
                return
            }
            
            temp[k] = array[j]
            j += 1
            k += 1
        }
        
        i = begin
        k = 0
        
        while i <= end {
            guard !workItem.isCancelled else {
                return
            }
            
            array[i] = temp[k]!
            i += 1
            k += 1
        }
    }
    
    class CancellationHandle {
        
        private let workItems: [DispatchWorkItem]
        
        fileprivate init(_ workItems: [DispatchWorkItem]) {
            self.workItems = workItems
        }
        
        func cancel() {
            workItems.forEach {
                $0.cancel()
            }
        }
    }
}
