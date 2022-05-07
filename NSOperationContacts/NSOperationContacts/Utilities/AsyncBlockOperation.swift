//
//  AsyncBlockOperation.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 38
 
 */

import Foundation // [lines: 1]


class AsyncBlockOperation : Operation { // [lines: 2]
    
    typealias CompletionHandler = () -> Void
    typealias OperationBlock = (_ completion: @escaping CompletionHandler) -> Void // [lines: 4]
    
    private let operationBlock: OperationBlock // [lines: 5]
    
    private var _isExecuting = false
    private var _isFinished = false // [lines: 7]
    
    override var isExecuting: Bool { _isExecuting }
    override var isFinished: Bool { _isFinished } // [lines: 9]
    
    init(_ block: @escaping OperationBlock) {
        self.operationBlock = block
    } // [lines: 12]
    
    override func start() {
        guard !self.isCancelled else {
            willChangeValue(forKey: "isFinished")
            _isFinished = true
            didChangeValue(forKey: "isFinished")
            return
        }
        
        willChangeValue(forKey: "isExecuting")
        main()
        _isExecuting = true
        didChangeValue(forKey: "isExecuting")
    } // [lines: 24]
    
    override func main() {
        operationBlock { [weak self] in
            guard let self = self else {
                return
            }
            
            self.willChangeValue(forKey: "isFinished")
            self.willChangeValue(forKey: "isExecuting")
            self._isExecuting = false
            self._isFinished = true
            self.didChangeValue(forKey: "isExecuting")
            self.didChangeValue(forKey: "isFinished")
        }
    } // [lines: 37]
} // [lines: 38]
