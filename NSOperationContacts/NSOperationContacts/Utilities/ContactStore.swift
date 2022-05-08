//
//  ContactStore.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 202
 
 TOTAL DEPENDENCY DEGREE: 112
 
 */

import Foundation
import Combine
import MetricKit // [lines: 3]


protocol ContactStoreListener : AnyObject {
    func contactStore(_ contactStore: ContactStore, didUpdate contacts: [Contact])
} // [lines: 6]

class ContactStore { // [lines: 7]
    
    static let shared = ContactStore() // [lines: 8]
    
    private static let fileName = "contacts"
    private static let fileExtension = "json" // [lines: 10]
    
    private var underlyingQueue: DispatchQueue
    private var operationQueue: OperationQueue
    private var timerCancellable: Cancellable? // [lines: 13]
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder() // [lines: 15]
    
    private var contactMap = [String : Contact]()
    private var listeners = [ListenerWrapper]() // [lines: 17]
    
    private var isLoaded = false
    private var hasContactsChanged = false // [lines: 19]
    
    private struct ListenerWrapper {
        weak var listener: ContactStoreListener?
        
        // [dd: 1]
        init(_ listener: ContactStoreListener) {
            self.listener = listener // [rd: { init listener } (1)]
        }
    } // [lines: 25]
    
    // [dd: 1]
    private init() {
        underlyingQueue = DispatchQueue(label: "ContactStore.Queue", qos: .default, target: .global())
        operationQueue = OperationQueue()
        operationQueue.underlyingQueue = underlyingQueue // [rd: { init underlyingQueue } (1)]
        operationQueue.maxConcurrentOperationCount = 1
    } // [lines: 31]
    
    // [dd: 3]
    func addListener(_ listener: ContactStoreListener) {
        // closure: [dd: 7]
        let operation = BlockOperation { [self, weak listener] in // [rd: { init listener } (1)]
            defer {
                // closure: [dd: 1]
                listeners.removeAll { $0.listener == nil /* [rd: { init $0.listener } (1)] */ } // [rd: { init listeners, listeners.append(ListenerWrapper(listener)) } (2)]
            }
            
            guard
                let listener = listener,
                // closure: [dd: 2]
                !listeners.contains(where: { $0.listener === listener } /* [rd: { let listener, init $0.listener } (2)] */ ) // [rd: { init listener, init listeners, let listener } (3)]
            else {
                return
            }
            
            listeners.append(ListenerWrapper(listener)) // [rd: { init listeners, let listener } (2)]
        }
        
        operation.qualityOfService = .userInteractive
        operation.queuePriority = .veryHigh
        
        operationQueue.addOperation(operation) // [rd: { init operationQueue, let operation } (2)]
    } // [lines: 48]
    
    // [dd: 3]
    func removeListener(_ listener: ContactStoreListener) {
        // closure: [dd: 6]
        let operation = BlockOperation { [self, weak listener] in // [rd: { init listener } (1)]
            guard let listener = listener else { // [rd: { weak listener } (1)]
                // closure: [dd: 1]
                listeners.removeAll(where: { $0.listener == nil } /* [rd: { init $0.listener } (1)] */ ) // [rd: { init listeners } (1)]
                return
            }
            
            // closure: [dd: 2]
            if let index = listeners.firstIndex(where: { $0.listener === listener } /* [rd: { init $0.listener, let listener } (2)] */ ) { // [rd: { init listeners, let listener } (2)]
                listeners.remove(at: index) // [rd: { init listeners, let index } (2)]
            }
        }
        
        operation.qualityOfService = .utility
        operation.queuePriority = .veryHigh
        
        operationQueue.addOperation(operation) // [rd: { init operationQueue, let operation } (2)]
    } // [lines: 62]
    
    // [dd: 2]
    func load() {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreLoadingSignpostName)
        
        // closure: [dd: 10]
        let operation = BlockOperation { [self] in
            defer {
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreLoadingSignpostName)
            }
            
            Logger.i("Trying to load contacts from persistent storage") // [rd: { init Logger } (1)]
            
            guard !isLoaded else { // [rd: { init isLoaded } (1)]
                Logger.v("Contacts already loaded") // [rd: { init Logger } (1)]
                return
            }
            
            defer {
                isLoaded = true
            }
            
            guard let fileUrl = getOrCreateFile() else {
                Logger.e("getOrCreateFile() returned nil while loading contacts") // [rd: { init Logger } (1)]
                return
            }

            startContactSaver(fileUrl) // [rd: { let fileUrl } (1)]
            
            guard let contents = FileManager.default.contents(atPath: fileUrl.path) else { // [rd: { (let fileUrl).path } (1)]
                Logger.e("Contact file contents are nil") // [rd: { init Logger } (1)]
                return
            }
            
            contactMap = (try? decoder.decode([String : Contact].self, from: contents)) ?? [:] // [rd: { init decoder, let contents } (2)]
            
            Logger.i("Contacts are successfully loaded") // [rd: { init Logger } (1)]
            
            notifyListenersContactsUpdated()
        }
        
        operation.qualityOfService = .userInteractive
        operation.queuePriority = .high

        operationQueue.addOperation(operation) // [rd: { init operationQueue, let operation } (2)]
    } // [lines: 89]
    
    // [dd: 3]
    func getContacts(_ completion: @escaping ([Contact]) -> Void) {
        // closure: [dd: 2]
        let operation = BlockOperation { [self] in // [rd: { init completion } (1)]
            completion(Array(contactMap.values)) // [rd: { init completion, init contactMap.values } (2)]
        }
        
        operation.qualityOfService = .userInteractive
        operation.queuePriority = .high
        
        operationQueue.addOperation(operation) // [rd: { init operationQueue, let operation } (2)]
    } // [lines: 97]
    
    // [dd: 1]
    func storeContact(_ contact: Contact) {
        storeContacts([contact]) // [rd: { init contact } (1)]
    } // [lines: 100]
    
    // [dd: 3]
    func storeContacts(_ contacts: [Contact]) {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
        
        // closure: [dd: 17]
        let operation = BlockOperation { [self] in // [rd: { init contacts } (1)]
            defer {
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
            }
            
            guard isLoaded else { // [rd: { init isLoaded } (1)]
                fatalError()
            }
            
            var updated = false
            
            for contact in contacts { // [rd: { init contacts } (1)]
                if contactMap.keys.contains(contact.identifier) { // [rd: { init contactMap.keys, (contactMap[contact.identifier] = ...) x 2, (for contact).identifier } (4)]
                    if contact != contactMap[contact.identifier]! { // [rd: { (for contact), (for contact).identifier, init contactMap, (contactMap[contact.identifier] = ...) x 2 } (5)]
                        contactMap[contact.identifier] = contact // [rd: { (for contact) } (1)]
                        updated = true
                    }
                } else {
                    contactMap[contact.identifier] = contact // [rd: { (for contact)) } (1)]
                    updated = true
                }
            }
            
            if updated { // [rd: { var updated = false, updated = true, updated = true } (3)]
                Logger.i("Stored contact updates") // [rd: { init Logger } (1)]
                hasContactsChanged = true
                notifyListenersContactsUpdated()
            }
        }
        
        operation.qualityOfService = .utility
        
        operationQueue.addOperation(operation) // [rd: { init operationQueue, init operation } (2)]
    } // [lines: 126]
    
    // [dd: 1]
    func deleteContact(_ identifier: String) {
        deleteContacts([identifier]) // [rd: { init identifier } (1)]
    } // [lines: 129]
    
    // [dd: 3]
    func deleteContacts(_ identifiers: Set<String>) {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreDeleting)
        
        // closure: [dd: 10]
        let operation = BlockOperation { [self] in // [rd: { init identifiers } (1)]
            defer {
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreDeleting)
            }
            
            guard isLoaded else { // [rd: { init isLoaded } (1)]
                fatalError()
            }
            
            var deleted = false
            
            for identifier in identifiers where contactMap.keys.contains(identifier) { // [rd: { init identifiers, init contactMap.keys, contactMap.removeValue(...), (for identifier) } (4)]
                contactMap.removeValue(forKey: identifier) // [rd: { init contactMap, contactMap.removeValue(...) } (2)]
                deleted = true
            }
            
            if deleted { // [rd: { var deleted = false, deleted = true } (2)]
                Logger.i("Deleted some contacts") // [rd: { init Logger } (1)]
                hasContactsChanged = true
                notifyListenersContactsUpdated()
            }
        }
        
        operation.qualityOfService = .utility
        
        operationQueue.addOperation(operation) // [rd: { init operationQueue, let operation } (2)]
    } // [lines: 148]
    
    // [dd: 4]
    private func startContactSaver(_ fileUrl: URL) {
        guard timerCancellable == nil else { // [rd: { init timerCancellable } (1)]
            return
        }
        
        Logger.i("Starting contact saver") // [rd: { init Logger } (1)]
        
        var firstEvent = true // Not counted because it is needed only for mxSignpost
        
        // closure: [dd: 10]
        timerCancellable = operationQueue.schedule(after: .init(.init(timeIntervalSinceNow: 2)), interval: .seconds(2), tolerance: .milliseconds(500)) { [self] in // [rd: { init operationQueue, init fileUrl } (2)]
            if firstEvent { // Not counted because it is needed only for mxSignpost
                firstEvent = false
            } else {
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreTimerFrequency)
            }
            
            defer {
                mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreTimerFrequency)
            }
            
            Logger.v("Checking for contact updates") // [rd: { init Logger } (1)]
            
            guard hasContactsChanged else { // [rd: { init hasContactsChanged } (1)]
                return
            }
            
            Logger.i("Contacts changed, storing changes to persistent storage") // [rd: { init Logger } (1)]
            
            hasContactsChanged = false
                        
            do {
                let data = try encoder.encode(contactMap) // [rd: { init encoder, init contactMap } (2)]
                try data.write(to: fileUrl) // [rd: { let data, init fileUrl } (2)]
                Logger.i("Contact changes stored to persistent storage successfully") // [rd: { init Logger } (1)]
            } catch {
                Logger.e("Failed to store contact changes to persistent storage [error=\(error)]") // [rd: { init Logger, init error } (2)]
            }
        }
    } // [lines: 169]
    
    // [dd: 2]
    private func notifyListenersContactsUpdated() {
        // closure: [dd: 1]
        listeners.removeAll { $0.listener == nil /* [rd: { init $0.listener } (1)] */  } // [rd: { init listeners } (1)]
        // closure: [dd: 2]
        listeners.forEach { // [rd: { listeners.removeAll() } (1)]
            $0.listener?.contactStore(self, didUpdate: Array(contactMap.values)) // [rd: { init $0.listener, init contactMap.values } (2)]
        }
    } // [lines: 175]
    
    // [dd: 6]
    private func getOrCreateFile() -> URL? {
        guard let fileUrl = getFileUrl() else {
            return nil
        }
        
        if !FileManager.default.fileExists(atPath: fileUrl.path) { // [rd: { (let fileUrl).path, FileManager.default } (2)]
            if FileManager.default.createFile(atPath: fileUrl.path, contents: nil, attributes: nil) { // [rd: { FileManager.default, (let fileUrl.path) } (2)]
                return fileUrl // [rd: { let fileUrl } (1)]
            }
        }
        
        return fileUrl // [rd: { let fileUrl } (1)]
    } // [lines: 186]
    
    // [dd: 4]
    private func getFileUrl() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { // [rd: { FileManager.default } (1)]
            return nil
        }
        
        return documentsDirectory.appendingPathComponent(Self.fileName).appendingPathExtension(Self.fileExtension) // [rd: { let documentsDirectory, init Self.fileName, init Self.fileExtension } (3)]
    } // [lines: 192]
} // [lines: 193]

extension ContactStore : Archivable {
    
    // [dd: 3]
    func getArchivableUrl(_ completion: @escaping (URL?) -> Void) {
        // closure: [dd: 1]
        let operation = BlockOperation { [self] in // [rd: { init completion } (1)]
            completion(getFileUrl()) // [rd: { init completion } (1)]
        }
        
        operation.qualityOfService = .userInteractive
        
        operationQueue.addOperation(operation) // [rd: { init operationQueue, init operation } (2)]
    }
} // [lines: 202]
