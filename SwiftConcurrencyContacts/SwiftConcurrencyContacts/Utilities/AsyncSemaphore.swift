//
//  AsyncSemaphore.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 30/04/2022.
//

import Foundation


actor AsyncSemaphore {
    
    private let limit: Int
    private var count = 0
    private var queue = [UnsafeContinuation<Void, Never>]()
    
    init(_ limit: Int = 1) {
        precondition(limit > 0)
        self.limit = limit
    }
    
    func acquire() async {
        if count < limit {
            count += 1
        } else {
            return await withUnsafeContinuation { continuation in
                queue.append(continuation)
            }
        }
    }
    
    func release() {
        precondition(count > 0)
        
        if queue.isEmpty {
            count -= 1
        } else {
            queue.removeFirst().resume()
        }
    }
    
    func synchronize<T>(_ block: @Sendable () async throws -> T) async rethrows -> T {
        await acquire()
        
        defer {
            release()
        }
        
        return try await block()
    }
}
