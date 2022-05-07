//
//  ContactStore.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 13/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 188
 
 */

import Foundation
import MetricKit // [lines: 2]


protocol ContactStoreListener : AnyObject {
    func contactStore(_ contactStore: ContactStore, didUpdate contacts: [Contact])
} // [lines: 5]

class ContactStore { // [lines: 6]
    
    static let shared = ContactStore() // [lines: 7]
    
    private static let fileName = "contacts"
    private static let fileExtension = "json" // [lines: 9]
    
    private let interactiveQueue: DispatchQueue
    private let utilityQueue: DispatchQueue
    private let targetQueue: DispatchQueue
    private var timer: DispatchSourceTimer? // [lines: 13]
    
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
        self.targetQueue = DispatchQueue(label: "ContactStore.TargetQeueu", qos: .default, target: .global())
        self.interactiveQueue = DispatchQueue(label: "ContactStore.InteractiveQueue", qos: .userInteractive, target: targetQueue)
        self.utilityQueue = DispatchQueue(label: "ContactStore.UtilityQueue", qos: .utility, target: targetQueue)
    } // [lines: 30]
    
    func addListener(_ listener: ContactStoreListener) {
        interactiveQueue.async { [self, weak listener] in
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
    } // [lines: 44]
    
    func removeListener(_ listener: ContactStoreListener) {
        utilityQueue.async { [self, weak listener] in
            defer {
                listeners.removeAll(where: { $0.listener == nil })
            }
            
            guard let listener = listener else {
                return
            }
            
            if let index = listeners.firstIndex(where: { $0.listener === listener }) {
                listeners.remove(at: index)
            }
        }
    } // [lines: 57]
    
    func load() {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreLoadingSignpostName)
        
        interactiveQueue.async { [self] in
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
    } // [lines: 81]
    
    func getContacts(_ completion: @escaping ([Contact]) -> Void) {
        interactiveQueue.async { [self] in
            completion(Array(contactMap.values))
        }
    } // [lines: 86]
    
    func storeContact(_ contact: Contact) {
        storeContacts([contact])
    } // [lines: 89]
    
    func storeContacts(_ contacts: [Contact]) {
        utilityQueue.async { [self] in
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
    } // [lines: 113]
    
    func deleteContact(_ identifier: String) {
        deleteContacts([identifier])
    } // [lines: 116]
    
    func deleteContacts(_ identifiers: Set<String>) {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreDeleting)
        
        utilityQueue.async { [self] in
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
    } // [lines: 133]
    
    private func startContactSaver(_ fileUrl: URL) {
        guard timer == nil else {
            return
        }
        
        Logger.i("Starting contact saver")
        
        var firstEvent = true // Not counted because it is only used for mxSignpost
        
        timer = DispatchSource.makeTimerSource(queue: utilityQueue)
        timer!.schedule(deadline: .now() + 2, repeating: .seconds(2), leeway: .milliseconds(500))
        timer!.setEventHandler { [self] in
            if firstEvent { // Not counted because it is only used for mxSignpost
                firstEvent = false
            } else {
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreTimerFrequency)
            }
            
            defer {
                mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreTimerFrequency)
            }
            
            Logger.v("Checking for contact updates")
            
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
    } // [lines: 157]
    
    private func notifyListenersContactsUpdated() {
        listeners.removeAll { $0.listener == nil }
        listeners.forEach {
            $0.listener?.contactStore(self, didUpdate: Array(contactMap.values))
        }
    } // [lines: 163]
    
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
    } // [lines: 174]
    
    private func getFileUrl() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return documentsDirectory.appendingPathComponent(Self.fileName).appendingPathExtension(Self.fileExtension)
    }
} // [lines: 181]

extension ContactStore : Archivable {
    
    func getArchivableUrl(_ completion: @escaping (URL?) -> Void) {
        interactiveQueue.async { [self] in
            completion(getFileUrl())
        }
    }
} // [lines: 188]
