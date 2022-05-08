//
//  ContactStore.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 13/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 188
 
 TOTAL DEPENDENCY DEGREE: 110
 
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
        
        // [dd: 1]
        init(_ listener: ContactStoreListener) {
            self.listener = listener // [rd: { init listener } (1)]
        }
    } // [lines: 25]
    
    // [dd: 2]
    private init() {
        self.targetQueue = DispatchQueue(label: "ContactStore.TargetQeueu", qos: .default, target: .global())
        self.interactiveQueue = DispatchQueue(label: "ContactStore.InteractiveQueue", qos: .userInteractive, target: targetQueue) // [rd: { self.targetQueue = ... } (1)]
        self.utilityQueue = DispatchQueue(label: "ContactStore.UtilityQueue", qos: .utility, target: targetQueue) // [rd: { self.targetQueue = ... } (1)]
    } // [lines: 30]
    
    // [dd: 2]
    func addListener(_ listener: ContactStoreListener) {
        // closure: [dd: 7]
        interactiveQueue.async { [self, weak listener] in // [rd: { init interactiveQueue, init listener } (2)]
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
    } // [lines: 44]
    
    // [dd: 2]
    func removeListener(_ listener: ContactStoreListener) {
        // closure: [dd: 7]
        utilityQueue.async { [self, weak listener] in // [rd: { init utilityQueue, init listener } (2)]
            defer {
                // closure: [dd: 1]
                listeners.removeAll(where: { $0.listener == nil } /* [rd: { init $0.listener } (1)] */ ) // [rd: { init listeners, listeners.remove(at: index) } (2)]
            }
            
            guard let listener = listener else { // [rd: { init listener } (1)]
                return
            }
            
            // closure: [dd: 2]
            if let index = listeners.firstIndex(where: { $0.listener === listener } /* [rd: { init $0.listener, let listener } (2)] */) { // [rd: { init listeners, let listener } (2)]
                listeners.remove(at: index) // [rd: { init listeners, let index } (2)]
            }
        }
    } // [lines: 57]
    
    // [dd: 1]
    func load() {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreLoadingSignpostName)
        
        // closure: [dd: 10]
        interactiveQueue.async { [self] in // [rd: { init interactiveQueue } (1)]
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
    } // [lines: 81]
    
    // [dd: 2]
    func getContacts(_ completion: @escaping ([Contact]) -> Void) {
        // closure: [dd: 2]
        interactiveQueue.async { [self] in // [rd: { init interactiveQueue, init completion } (2)]
            completion(Array(contactMap.values)) // [rd: { init completion, init contactMap.values } (2)]
        }
    } // [lines: 86]
    
    // [dd: 1]
    func storeContact(_ contact: Contact) {
        storeContacts([contact]) // [rd: { init contact } (1)]
    } // [lines: 89]
    
    // [dd: 2]
    func storeContacts(_ contacts: [Contact]) {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
        
        // closure: [dd: 17]
        utilityQueue.async { [self] in // [rd: { init utilityQueue, init contacts } (2)]
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
    } // [lines: 113]
    
    // [dd: 1]
    func deleteContact(_ identifier: String) {
        deleteContacts([identifier]) // [rd: { init identifier } (1)]
    } // [lines: 116]
    
    // [dd: 2]
    func deleteContacts(_ identifiers: Set<String>) {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreDeleting)
        // closure: [dd: 10]
        utilityQueue.async { [self] in // [rd: { init identifiers, init utilityQueue } (2)]
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
    } // [lines: 133]
    
    // [dd: 7]
    private func startContactSaver(_ fileUrl: URL) {
        guard timer == nil else { // [rd: { init timer } (1)]
            return
        }
        
        Logger.i("Starting contact saver") // [rd: { init Logger } (1)]
        
        var firstEvent = true // Not counted because it is only used for mxSignpost
        
        timer = DispatchSource.makeTimerSource(queue: utilityQueue) // [rd: { init utilityQueue } (1)]
        timer!.schedule(deadline: .now() + 2, repeating: .seconds(2), leeway: .milliseconds(500)) // [rd: { timer = DispatchSource... } (1)]
        
        // closure: [dd: 10]
        timer!.setEventHandler { [self] in // [rd: { timer = DispatchSource..., init fileUrl } (2)]
            if firstEvent { // Not counted because it is only used for mxSignpost
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
        
        timer!.resume() // [rd: { timer = DispatchSource... } (1)]
    } // [lines: 157]
    
    // [dd: 2]
    private func notifyListenersContactsUpdated() {
        // closure: [dd: 1]
        listeners.removeAll { $0.listener == nil /* [rd: { init $0.listener } (1)] */  } // [rd: { init listeners } (1)]
        // closure: [dd: 2]
        listeners.forEach { // [rd: { listeners.removeAll() } (1)]
            $0.listener?.contactStore(self, didUpdate: Array(contactMap.values)) // [rd: { init $0.listener, init contactMap.values } (2)]
        }
    } // [lines: 163]
    
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
    } // [lines: 174]
    
    // [dd: 4]
    private func getFileUrl() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { // [rd: { FileManager.default } (1)]
            return nil
        }
        
        return documentsDirectory.appendingPathComponent(Self.fileName).appendingPathExtension(Self.fileExtension) // [rd: { let documentsDirectory, init Self.fileName, init Self.fileExtension } (3)]
    }
} // [lines: 181]

extension ContactStore : Archivable {

    // [dd: 2]
    func getArchivableUrl(_ completion: @escaping (URL?) -> Void) {
        // closure: [dd: 1]
        interactiveQueue.async { [self] in // [rd: { init interactiveQueue, init completion } (2)]
            completion(getFileUrl()) // [rd: { init completion } (1)]
        }
    }
} // [lines: 188]
