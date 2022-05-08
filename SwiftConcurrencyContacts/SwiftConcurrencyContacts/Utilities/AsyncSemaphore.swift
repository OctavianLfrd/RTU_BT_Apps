//
//  AsyncSemaphore.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 30/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 34
 
 TOTAL DEPENDENCY DEGREE: 12
 
 */

import Foundation // [lines: 1]


actor AsyncSemaphore { // [lines: 2]
    
    private let limit: Int
    private var count = 0
    private var queue = [UnsafeContinuation<Void, Never>]() // [lines: 5]
    
    // [dd: 2]
    init(_ limit: Int = 1) {
        precondition(limit > 0) // [rd: { init limit } (1)]
        self.limit = limit // [rd: { init limit } (1)]
    } // [lines: 9]
    
    // [dd: 3]
    func acquire() async {
        if count < limit { // [rd: { init count, init limit } (2)]
            count += 1 // [rd: { init count } (1)]
        } else {
            // closure: [dd: 2]
            return await withUnsafeContinuation { continuation in
                queue.append(continuation) // [rd: { init queue, init continuation } (2)]
            }
        }
    } // [lines: 18]
    
    // [dd: 4]
    func release() {
        precondition(count > 0) // [rd: { init count } (1)]
        
        if queue.isEmpty { // [rd: { init queue } (1)]
            count -= 1 // [rd: { init count } (1)]
        } else {
            queue.removeFirst().resume() // [rd: { init queue } (1)]
        }
    } // [lines: 26]
    
    // [dd: 1]
    func synchronize<T>(_ block: @Sendable () async throws -> T) async rethrows -> T {
        await acquire()
        
        defer {
            release()
        }
        
        return try await block() // [rd: { init block } (1)]
    } // [lines: 33]
} // [lines: 34]
