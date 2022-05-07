//
//  AsyncSemaphore.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 30/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 34
 
 */

import Foundation // [lines: 1]


actor AsyncSemaphore { // [lines: 2]
    
    private let limit: Int
    private var count = 0
    private var queue = [UnsafeContinuation<Void, Never>]() // [lines: 5]
    
    init(_ limit: Int = 1) {
        precondition(limit > 0)
        self.limit = limit
    } // [lines: 9]
    
    func acquire() async {
        if count < limit {
            count += 1
        } else {
            return await withUnsafeContinuation { continuation in
                queue.append(continuation)
            }
        }
    } // [lines: 18]
    
    func release() {
        precondition(count > 0)
        
        if queue.isEmpty {
            count -= 1
        } else {
            queue.removeFirst().resume()
        }
    } // [lines: 26]
    
    func synchronize<T>(_ block: @Sendable () async throws -> T) async rethrows -> T {
        await acquire()
        
        defer {
            release()
        }
        
        return try await block()
    } // [lines: 33]
} // [lines: 34]
