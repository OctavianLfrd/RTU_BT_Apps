//
//  AsyncBlockOperation.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 38
 
 TOTAL DEPENDENCY DEGREE: 9
 
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
    
    // [dd: 1]
    init(_ block: @escaping OperationBlock) {
        self.operationBlock = block // [rd: { init block } (1)]
    } // [lines: 12]
    
    // [dd: 1]
    override func start() {
        guard !self.isCancelled else { // [rd: { init isCancelled } (1)]
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
    
    // [dd: 0]
    override func main() {
        // closure: [dd: 7]
        operationBlock { [weak self] in
            guard let self = self else { // [rd: { weak self } (1)]
                return
            }
            
            self.willChangeValue(forKey: "isFinished") // [rd: { let self } (1)]
            self.willChangeValue(forKey: "isExecuting") // [rd: { let self } (1)]
            self._isExecuting = false // [rd: { let self } (1)]
            self._isFinished = true // [rd: { let self } (1)]
            self.didChangeValue(forKey: "isExecuting") // [rd: { let self } (1)]
            self.didChangeValue(forKey: "isFinished") // [rd: { let self } (1)]
        }
    } // [lines: 37]
} // [lines: 38]
