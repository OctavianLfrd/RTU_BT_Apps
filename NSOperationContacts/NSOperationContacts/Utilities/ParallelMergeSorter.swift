//
//  ParallelMergeSorter.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

import Foundation


class ParallelMergeSorter<T> {
    
    typealias Comparator = (T, T) -> Bool
    
    private var underlyingQueue: DispatchQueue?
    private let operationQueue: OperationQueue
    
    init(_ sortQueue: OperationQueue? = nil) {
        if let sortQueue = sortQueue {
            self.operationQueue = sortQueue
        } else {
            operationQueue = OperationQueue()
            underlyingQueue = DispatchQueue(label: "ParallelMergeSorter.Queue", qos: .utility, attributes: .concurrent, target: .global(qos: .utility))
            operationQueue.underlyingQueue = underlyingQueue
        }
    }
    
    func sort(_ array: [T], parallelismLevel: Int = ProcessInfo.processInfo.processorCount, comparator: @escaping Comparator, completion: @escaping ([T]) -> Void) -> CancellationHandle {
        var array = array
        let chunksEqual = array.count % parallelismLevel == 0
        
        operationQueue.maxConcurrentOperationCount = parallelismLevel
        
        let limit = max(parallelismLevel, chunksEqual ? (array.count / parallelismLevel) : (array.count / (parallelismLevel - 1)))
        
        let completionOperation = BlockOperation {
            completion(array)
        }
        
        var i = 0
        while i < array.count {
            let begin = i
            let remaining = array.count - i
            let end = remaining < limit ? (i + remaining - 1) : (i + limit - 1)
            
            operationQueue.addOperation { [weak self] in
                guard let self = self, !completionOperation.isCancelled else {
                    return
                }
                
                self.mergeSort(&array, begin: begin, end: end, comparator: comparator, isCancelled: completionOperation.isCancelled)
            }
            
            i += limit
        }
        
        operationQueue.addBarrierBlock { [weak self] in
            guard let self = self, !completionOperation.isCancelled else {
                return
            }
                
            var i = 0
            while i < array.count {
                guard !completionOperation.isCancelled else {
                    return
                }
                
                let middle = max(i - 1, 0)
                let remaining = array.count - i
                let end = remaining < limit ? (i + remaining - 1) : (i + limit - 1)
                
                self.merge(&array, begin: 0, middle: middle, end: end, comparator: comparator, isCancelled: completionOperation.isCancelled)
                
                i += limit
            }
            
            completionOperation.start()
        }
        
        return CancellationHandle(completionOperation)
    }
    
    private func mergeSort(_ array: inout [T], begin: Int, end: Int, comparator: Comparator, isCancelled: @autoclosure () -> Bool) {
        guard begin < end, !isCancelled() else {
            return
        }
        
        let middle = (begin + end) / 2
        
        mergeSort(&array, begin: begin, end: middle, comparator: comparator, isCancelled: isCancelled())
        mergeSort(&array, begin: middle + 1, end: end, comparator: comparator, isCancelled: isCancelled())
        
        merge(&array, begin: begin, middle: middle, end: end, comparator: comparator, isCancelled: isCancelled())
    }
    
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
    }
    
    struct CancellationHandle {
        
        private let operation: Operation
        
        fileprivate init(_ operation: Operation) {
            self.operation = operation
        }
        
        func cancel() {
            operation.cancel()
        }
    }
}
