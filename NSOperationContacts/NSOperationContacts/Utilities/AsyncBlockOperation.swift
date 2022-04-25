//
//  AsyncBlockOperation.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

import Foundation


class AsyncBlockOperation : Operation {
    
    typealias CompletionHandler = () -> Void
    typealias OperationBlock = (_ completion: @escaping CompletionHandler) -> Void
    
    private let operationBlock: OperationBlock
    
    private var _isExecuting = false
    private var _isFinished = false
    
    override var isExecuting: Bool { _isExecuting }
    override var isFinished: Bool { _isFinished }
    
    init(_ block: @escaping OperationBlock) {
        self.operationBlock = block
    }
    
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
    }
    
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
    }
}
