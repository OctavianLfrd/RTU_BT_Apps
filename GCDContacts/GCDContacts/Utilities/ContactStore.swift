//
//  ContactStore.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 13/04/2022.
//

import Foundation


protocol ContactStoreListener : AnyObject {
    func contactStore(_ contactStore: ContactStore, didUpdate contacts: [Contact])
}

class ContactStore {
    
    static let shared = ContactStore()
    
    private static let fileName = "contacts"
    private static let fileExtension = "json"
    
    private let readQueue: DispatchQueue
    private let writeQueue: DispatchQueue
    private let targetQueue: DispatchQueue
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var contactMap = [String : Contact]()
    private var isLoaded = false
    private var listeners = [ListenerWrapper]()
    
    private struct ListenerWrapper {
        weak var listener: ContactStoreListener?
        
        init(_ listener: ContactStoreListener) {
            self.listener = listener
        }
    }
    
    private init() {
        self.targetQueue = DispatchQueue(label: "ContactStore.TargetQeueu", qos: .default, target: .global())
        self.readQueue = DispatchQueue(label: "ContactStore.ReadQueue", qos: .userInteractive, target: targetQueue)
        self.writeQueue = DispatchQueue(label: "ContactStore.UpdateQueue", qos: .utility, target: targetQueue)
    }
    
    func addListener(_ listener: ContactStoreListener) {
        writeQueue.async { [self, weak listener] in
            guard
                let listener = listener,
                !listeners.contains(where: { $0.listener === listener })
            else {
                return
            }
            
            listeners.removeAll { $0.listener == nil }
            listeners.append(ListenerWrapper(listener))
        }
    }
    
    func removeListener(_ listener: ContactStoreListener) {
        writeQueue.async { [self, weak listener] in
            guard let listener = listener else {
                listeners.removeAll(where: { $0.listener == nil })
                return
            }
            
            if let index = listeners.firstIndex(where: { $0.listener === listener }) {
                listeners.remove(at: index)
            }
        }
    }
    
    func load() {
        readQueue.async { [self] in
            if restoreContacts() {
                notifyListenersContactsUpdated()
            }
        }
    }
    
    func getContacts(_ completion: @escaping ([Contact]) -> Void) {
        readQueue.async { [self] in
            completion(Array(contactMap.values))
        }
    }
    
    func storeContact(_ contact: Contact) {
        storeContacts([contact])
    }
    
    func storeContacts(_ contacts: [Contact]) {
        writeQueue.async { [self] in
            restoreContacts()
            
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
                saveContacts()
                notifyListenersContactsUpdated()
            }
        }
    }
    
    func deleteContact(_ identifier: String) {
        deleteContacts([identifier])
    }
    
    func deleteContacts(_ identifiers: Set<String>) {
        writeQueue.async { [self] in
            restoreContacts()
            
            var deleted = false
            
            for identifier in identifiers where contactMap.keys.contains(identifier) {
                contactMap.removeValue(forKey: identifier)
                deleted = true
            }
            
            if deleted {
                saveContacts()
                notifyListenersContactsUpdated()
            }
        }
    }
    
    @discardableResult
    private func restoreContacts() -> Bool {
        guard !isLoaded else {
            return false
        }
        
        defer {
            isLoaded = true
        }
        
        guard let fileUrl = self.getFileUrlIfExists() else {
            return true
        }
        
        guard let contents = FileManager.default.contents(atPath: fileUrl.path) else {
            return true
        }
        
        contactMap = (try? decoder.decode([String : Contact].self, from: contents)) ?? [:]
        
        return true
    }
    
    private func saveContacts() {
        guard let fileUrl = getOrCreateFile() else {
            return
        }
        
        do {
            let data = try encoder.encode(contactMap)
            try data.write(to: fileUrl, options: .atomic)
        } catch {
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
    
    private func getFileUrlIfExists() -> URL? {
        guard let fileUrl = getFileUrl() else {
            return nil
        }
        
        return FileManager.default.fileExists(atPath: fileUrl.path) ? fileUrl : nil
    }
    
    private func getFileUrl() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return documentsDirectory.appendingPathComponent(Self.fileName).appendingPathExtension(Self.fileExtension)
    }
}