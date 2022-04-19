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
    private var timer: DispatchSourceTimer?
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private var contactMap = [String : Contact]()
    private var listeners = [ListenerWrapper]()
    
    private var isLoaded = false
    private var hasContactsChanged = false
    
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
    }
    
    func deleteContact(_ identifier: String) {
        deleteContacts([identifier])
    }
    
    func deleteContacts(_ identifiers: Set<String>) {
        writeQueue.async { [self] in
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
    }
    
    private func startContactSaver(_ fileUrl: URL) {
        guard timer == nil else {
            return
        }
        
        Logger.i("Starting contact saver")
        
        timer = DispatchSource.makeTimerSource(queue: writeQueue)
        timer!.schedule(deadline: .now() + 2, repeating: .seconds(2), leeway: .milliseconds(500))
        timer!.setEventHandler { [self] in
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
        
        timer!.resume()
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
    
    func getArchivableUrl(_ completion: @escaping (URL?) -> Void) {
        readQueue.async { [self] in
            completion(getFileUrl())
        }
    }
}
