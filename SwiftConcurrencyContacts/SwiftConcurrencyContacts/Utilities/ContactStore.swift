//
//  ContactStore.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 30/04/2022.
//

import Foundation
import MetricKit


protocol ContactStoreListener : AnyObject {
    func contactStore(_ contactStore: ContactStore, didUpdate contacts: [Contact])
}

actor ContactStore {
    
    static let shared = ContactStore()
    
    private static let fileName = "contacts"
    private static let fileExtension = "json"
    
    private var timerTask: Task<Void, Never>?
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private var contactMap = [String : Contact]()
    private var listeners = [ListenerWrapper]()
    
    private var isLoaded = false
    private var hasContactsChanged = false
    
    private class ListenerWrapper {
        weak var listener: ContactStoreListener?
        
        init(_ listener: ContactStoreListener) {
            self.listener = listener
        }
    }
    
    private init() {
    }
    
    func addListener(_ listener: ContactStoreListener) {
        defer {
            listeners.removeAll(where: { $0.listener == nil })
        }
        
        guard !listeners.contains(where: { $0.listener === listener }) else {
            return
        }
        
        listeners.append(ListenerWrapper(listener))
    }
    
    func removeListener(_ listener: ContactStoreListener) {
        listeners.removeAll(where: { $0.listener == nil })
        
        if let index = listeners.firstIndex(where: { $0.listener === listener }) {
            listeners.remove(at: index)
        }
    }
    
    func load() {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreLoadingSignpostName)
        
        Task(priority: .high) {
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
    }
    
    func getContacts() async -> [Contact] {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreFetching)
        
        defer {
            mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreFetching)
        }
        
        return Array(contactMap.values)
    }
    
    func storeContact(_ contact: Contact) {
        storeContacts([contact])
    }
    
    func storeContacts(_ contacts: [Contact]) {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
        
        defer {
            mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
        }
        
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
    }
    
    func deleteContact(_ identifier: String) {
        deleteContacts([identifier])
    }
    
    func deleteContacts(_ identifier: Set<String>) {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreDeleting)
        
        defer {
            mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreDeleting)
        }
        
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
    }
    
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
    }
    
    private func notifyListenersContactsUpdated() {
        listeners.removeAll { $0.listener == nil }
        listeners.forEach {
            $0.listener?.contactStore(self, didUpdate: Array(contactMap.values))
        }
    }
    
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
    }
    
    private func getFileUrl() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return documentsDirectory.appendingPathComponent(Self.fileName).appendingPathExtension(Self.fileExtension)
    }
}

extension ContactStore : Archivable {
    
    func getArchivableUrl() async -> URL? {
        return getFileUrl()
    }
}
