//
//  ContactStore.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 30/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 161
 
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
    
    func addListener(_ listener: ContactStoreListener) {
        defer {
            listeners.removeAll(where: { $0.listener == nil })
        }
        
        guard !listeners.contains(where: { $0.listener === listener }) else {
            return
        }
        
        listeners.append(ListenerWrapper(listener))
    } // [lines: 33]
    
    func removeListener(_ listener: ContactStoreListener) {
        listeners.removeAll(where: { $0.listener == nil })
        
        if let index = listeners.firstIndex(where: { $0.listener === listener }) {
            listeners.remove(at: index)
        }
    } // [lines: 39]
    
    func load() {
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
    } // [lines: 61]
    
    func getContacts() async -> [Contact] {
        return Array(contactMap.values)
    } // [lines: 64]
    
    func storeContact(_ contact: Contact) {
        storeContacts([contact])
    } // [lines: 67]
    
    func storeContacts(_ contacts: [Contact]) {
        guard isLoaded else {
            fatalError()
        }
        
        var updated = false
        
        for contact in contacts {
            if contactMap.keys.contains(contact.identifier) {
                if contact != contactMap[contact.identifier] {
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
    } // [lines: 89]
    
    func deleteContact(_ identifier: String) {
        deleteContacts([identifier])
    } // [lines: 92]
    
    func deleteContacts(_ identifier: Set<String>) {
        guard isLoaded else {
            fatalError()
        }
        
        var deleted = false
        
        for identifier in identifier where contactMap.keys.contains(identifier) {
            contactMap.removeValue(forKey: identifier)
            deleted = true
        }
        
        if deleted {
            Logger.i("Deleted some contacts")
            hasContactsChanged = true
            notifyListenersContactsUpdated()
        }
    } // [lines: 107]
    
    private func startContactSaver(_ fileUrl: URL) {
        guard timerTask == nil else {
            return
        }
        
        Logger.i("Starting contact saver")
        
        timerTask = Task(priority: .low) {
            while true {
                mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreTimerFrequency)
                
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await Task.yield()
                
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreTimerFrequency)
                
                Logger.v("Checking for contact updates")
                
                guard hasContactsChanged else {
                    continue
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
        }
    } // [lines: 132]
    
    private func notifyListenersContactsUpdated() {
        listeners.removeAll { $0.listener == nil }
        listeners.forEach {
            $0.listener?.contactStore(self, didUpdate: Array(contactMap.values))
        }
    } // [lines: 138]
    
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
    } // [lines: 149]
    
    private func getFileUrl() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return documentsDirectory.appendingPathComponent(Self.fileName).appendingPathExtension(Self.fileExtension)
    } // [lines: 155]
} // [lines: 156]

extension ContactStore : Archivable {
    
    func getArchivableUrl() async -> URL? {
        return getFileUrl()
    }
} // [lines: 161]
