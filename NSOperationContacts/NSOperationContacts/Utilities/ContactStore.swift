//
//  ContactStore.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 202
 
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
        
        init(_ listener: ContactStoreListener) {
            self.listener = listener
        }
    } // [lines: 25]
    
    private init() {
        underlyingQueue = DispatchQueue(label: "ContactStore.Queue", qos: .default, target: .global())
        operationQueue = OperationQueue()
        operationQueue.underlyingQueue = underlyingQueue
        operationQueue.maxConcurrentOperationCount = 1
    } // [lines: 31]
    
    func addListener(_ listener: ContactStoreListener) {
        let operation = BlockOperation { [self, weak listener] in
            defer {
                listeners.removeAll { $0.listener == nil }
            }
            
            guard
                let listener = listener,
                !listeners.contains(where: { $0.listener === listener })
            else {
                return
            }
            
            listeners.append(ListenerWrapper(listener))
        }
        
        operation.qualityOfService = .userInteractive
        operation.queuePriority = .veryHigh
        
        operationQueue.addOperation(operation)
    } // [lines: 48]
    
    func removeListener(_ listener: ContactStoreListener) {
        let operation = BlockOperation { [self, weak listener] in
            guard let listener = listener else {
                listeners.removeAll(where: { $0.listener == nil })
                return
            }
            
            if let index = listeners.firstIndex(where: { $0.listener === listener }) {
                listeners.remove(at: index)
            }
        }
        
        operation.qualityOfService = .utility
        operation.queuePriority = .veryHigh
        
        operationQueue.addOperation(operation)
    } // [lines: 62]
    
    func load() {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreLoadingSignpostName)
        
        let operation = BlockOperation { [self] in
            defer {
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreLoadingSignpostName)
            }
            
            Logger.i("Trying to load contacts from persistent storage")
            
            guard !isLoaded else {
                Logger.v("Contacts already loaded")
                return
            }
            
            defer {
                isLoaded = true
            }
            
            guard let fileUrl = getOrCreateFile() else {
                Logger.e("getOrCreateFile() returned nil while loading contacts")
                return
            }
            
            startContactSaver(fileUrl)
            
            guard let contents = FileManager.default.contents(atPath: fileUrl.path) else {
                Logger.e("Contact file contents are nil")
                return
            }
            
            contactMap = (try? decoder.decode([String : Contact].self, from: contents)) ?? [:]
            
            Logger.i("Contacts are successfully loaded")
            
            notifyListenersContactsUpdated()
        }
        
        operation.qualityOfService = .userInteractive
        operation.queuePriority = .high

        operationQueue.addOperation(operation)
    } // [lines: 89]
    
    func getContacts(_ completion: @escaping ([Contact]) -> Void) {
        let operation = BlockOperation { [self] in
            completion(Array(contactMap.values))
        }
        
        operation.qualityOfService = .userInteractive
        operation.queuePriority = .high
        
        operationQueue.addOperation(operation)
    } // [lines: 97]
    
    func storeContact(_ contact: Contact) {
        storeContacts([contact])
    } // [lines: 100]
    
    func storeContacts(_ contacts: [Contact]) {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
        
        let operation = BlockOperation { [self] in
            defer {
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
            }
            
            guard isLoaded else {
                fatalError()
            }
            
            var updated = false
            
            for contact in contacts {
                if contactMap.keys.contains(contact.identifier) {
                    if contact != contactMap[contact.identifier]! {
                        contactMap[contact.identifier] = contact
                        updated = true
                    }
                } else {
                    contactMap[contact.identifier] = contact
                    updated = true
                }
            }
            
            if updated {
                Logger.i("Stored contact updates")
                hasContactsChanged = true
                notifyListenersContactsUpdated()
            }
        }
        
        operation.qualityOfService = .utility
        
        operationQueue.addOperation(operation)
    } // [lines: 126]
    
    func deleteContact(_ identifier: String) {
        deleteContacts([identifier])
    } // [lines: 129]
    
    func deleteContacts(_ identifiers: Set<String>) {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreDeleting)
        
        let operation = BlockOperation { [self] in
            defer {
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreDeleting)
            }
            
            guard isLoaded else {
                fatalError()
            }
            
            var deleted = false
            
            for identifier in identifiers where contactMap.keys.contains(identifier) {
                contactMap.removeValue(forKey: identifier)
                deleted = true
            }
            
            if deleted {
                Logger.i("Deleted some contacts")
                hasContactsChanged = true
                notifyListenersContactsUpdated()
            }
        }
        
        operation.qualityOfService = .utility
        
        operationQueue.addOperation(operation)
    } // [lines: 148]
    
    private func startContactSaver(_ fileUrl: URL) {
        guard timerCancellable == nil else {
            return
        }
        
        Logger.i("Starting contact saver")
        
        var firstEvent = true // Not counted because it is needed only for mxSignpost
        
        timerCancellable = operationQueue.schedule(after: .init(.init(timeIntervalSinceNow: 2)), interval: .seconds(2), tolerance: .milliseconds(500)) { [self] in
            if firstEvent { // Not counted because it is needed only for mxSignpost
                firstEvent = false
            } else {
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreTimerFrequency)
            }
            
            defer {
                mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreTimerFrequency)
            }
            
            Logger.v("Cheching for contact updates")
            
            guard hasContactsChanged else {
                return
            }
            
            Logger.i("Contacts changed, storing changes to persistent storage")
            
            hasContactsChanged = false
            
            do {
                let data = try encoder.encode(contactMap)
                try data.write(to: fileUrl)
                Logger.i("Contact changes stored to persistent storage successfully")
            } catch {
                Logger.e("Failed to store contact changes to persistent storage [error=\(error)]")
            }
        }
    } // [lines: 169]
    
    private func notifyListenersContactsUpdated() {
        listeners.removeAll { $0.listener == nil }
        listeners.forEach {
            $0.listener?.contactStore(self, didUpdate: Array(contactMap.values))
        }
    } // [lines: 175]
    
    private func getOrCreateFile() -> URL? {
        guard let fileUrl = getFileUrl() else {
            return nil
        }
        
        if !FileManager.default.fileExists(atPath: fileUrl.path) {
            if FileManager.default.createFile(atPath: fileUrl.path, contents: nil, attributes: nil) {
                return fileUrl
            }
        }
        
        return fileUrl
    } // [lines: 186]
    
    private func getFileUrl() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return documentsDirectory.appendingPathComponent(Self.fileName).appendingPathExtension(Self.fileExtension)
    } // [lines: 192]
} // [lines: 193]

extension ContactStore : Archivable {
    
    func getArchivableUrl(_ completion: @escaping (URL?) -> Void) {
        let operation = BlockOperation { [self] in
            completion(getFileUrl())
        }
        
        operation.qualityOfService = .userInteractive
        
        operationQueue.addOperation(operation)
    }
} // [lines: 202]
