//
//  ContactStore.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 30/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 161
 
 TOTAL DEPENDENCY DEGREE: 83
 
 */

import Foundation
import MetricKit // [lines: 2]


protocol ContactStoreListener : AnyObject {
    func contactStore(_ contactStore: ContactStore, didUpdate contacts: [Contact])
} // [lines: 5]

actor ContactStore { // [lines: 6]
    
    static let shared = ContactStore() // [lines: 7]
    
    private static let fileName = "contacts"
    private static let fileExtension = "json" // [lines: 9]
    
    private var timerTask: Task<Void, Never>? // [lines: 10]
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder() // [lines: 12]
    
    private var contactMap = [String : Contact]()
    private var listeners = [ListenerWrapper]() // [lines: 14]
    
    private var isLoaded = false
    private var hasContactsChanged = false // [lines: 16]
    
    private class ListenerWrapper {
        weak var listener: ContactStoreListener?
        
        init(_ listener: ContactStoreListener) {
            self.listener = listener
        }
    } // [lines: 22]
    
    private init() {
    } // [lines: 24]
    
    // [dd: 6]
    func addListener(_ listener: ContactStoreListener) {
        defer {
            // closure: [dd: 1]
            listeners.removeAll { $0.listener == nil /* [rd: { init $0.listener } (1)] */ } // [rd: { init listeners, listeners.append(ListenerWrapper(listener)) } (2)]
        }
        
        // closure: [dd: 2]
        guard !listeners.contains(where: { $0.listener === listener } /* [rd: { init listener, init $0.listener } (2)] */ ) else { // [rd: { init listeners, init listener } (2)]
            return
        }
        
        listeners.append(ListenerWrapper(listener)) // [rd: { init listeners, let listener } (2)]
    } // [lines: 33]
    
    // [dd: 5]
    func removeListener(_ listener: ContactStoreListener) {
        // closure: [dd: 1]
        listeners.removeAll(where: { $0.listener == nil } /* [rd: { init $0.listener } (1)] */) // [rd: { init listeners } (1)]
        
        // closure: [dd: 2]
        if let index = listeners.firstIndex(where: { $0.listener === listener } /* [rd: { init $0.listener, init listener } (2)] */ ) { // [rd: { init listeners, init listener } (2)]
            listeners.remove(at: index) // [rd: { init listeners, let index } (2)]
        }
    } // [lines: 39]
    
    // [dd: 9]
    func load() {
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
    } // [lines: 61]
    
    // [dd: 1]
    func getContacts() async -> [Contact] {
        return Array(contactMap.values) // [rd: { init contactMap.values } (1)]
    } // [lines: 64]
    
    // [dd: 1]
    func storeContact(_ contact: Contact) {
        storeContacts([contact]) // [rd: { init contact } (1)]
    } // [lines: 67]
    
    // [dd: 16]
    func storeContacts(_ contacts: [Contact]) {
        guard isLoaded else { // [rd: { init isLoaded } (1)]
            fatalError()
        }
        
        var updated = false
        
        for contact in contacts {
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
    } // [lines: 89]
    
    // [dd: 1]
    func deleteContact(_ identifier: String) {
        deleteContacts([identifier]) // [rd: { init identifier } (1)]
    } // [lines: 92]
    
    // [dd: 10]
    func deleteContacts(_ identifiers: Set<String>) {
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
    } // [lines: 107]
    
    // [dd: 3]
    private func startContactSaver(_ fileUrl: URL) {
        guard timerTask == nil else { // [rd: { init timerTask } (1)]
            return
        }
        
        Logger.i("Starting contact saver") // [rd: { init Logger } (1)]
        
        // closure: [dd: 10]
        timerTask = Task(priority: .low) { // [rd: { init fileUrl } (1)]
            while true {
                mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreTimerFrequency)
                
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await Task.yield()
                
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreTimerFrequency)
                
                Logger.v("Checking for contact updates") // [rd: { init Logger } (1)]
                
                guard hasContactsChanged else { // [rd: { init hasContactsChanged } (1)]
                    continue
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
        }
    } // [lines: 132]
    
    // [dd: 2]
    private func notifyListenersContactsUpdated() {
        // closure: [dd: 1]
        listeners.removeAll { $0.listener == nil /* [rd: { init $0.listener } (1)] */  } // [rd: { init listeners } (1)]
        // closure: [dd: 2]
        listeners.forEach { // [rd: { listeners.removeAll() } (1)]
            $0.listener?.contactStore(self, didUpdate: Array(contactMap.values)) // [rd: { init $0.listener, init contactMap.values } (2)]
        }
    } // [lines: 138]
    
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
    } // [lines: 149]
    
    // [dd: 4]
    private func getFileUrl() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { // [rd: { FileManager.default } (1)]
            return nil
        }
        
        return documentsDirectory.appendingPathComponent(Self.fileName).appendingPathExtension(Self.fileExtension) // [rd: { let documentsDirectory, init Self.fileName, init Self.fileExtension } (3)]
    } // [lines: 155]
} // [lines: 156]

extension ContactStore : Archivable {
    
    // [dd: 0]
    func getArchivableUrl() async -> URL? {
        return getFileUrl()
    }
} // [lines: 161]
