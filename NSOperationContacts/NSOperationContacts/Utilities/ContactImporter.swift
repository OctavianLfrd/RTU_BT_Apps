//
//  ContactImporter.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

import Foundation
import Contacts
import MetricKit


class ContactImporter {
    
    typealias ImportCompletion = (Result) -> Void
    
    static let shared = ContactImporter()
    
    private let operationQueue: OperationQueue
    private let underlyingQueue: DispatchQueue
    
    private init() {
        underlyingQueue = DispatchQueue(label: "ContactImporter.Queue", qos: .userInitiated, target: .global(qos: .userInitiated))
        operationQueue = OperationQueue()
        operationQueue.underlyingQueue = underlyingQueue
        operationQueue.maxConcurrentOperationCount = 1
    }
    
    func importContacts(completion: @escaping ImportCompletion) {
        Logger.i("Contact import started")
        
        let authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        
        switch authorizationStatus {
        case .authorized:
            Logger.i("Contact import authorized, proceeding")
            
            mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
            
            operationQueue.addOperation { [self] in
                _importContacts(CNContactStore()) { result in
                    defer {
                        mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
                    }
                    
                    completion(result)
                }
            }
        case .notDetermined:
            Logger.i("Contact import authorization status notDetermined, requesting permission")
            
            let contactStore = CNContactStore()
            contactStore.requestAccess(for: .contacts) { [self] granted, error in
                guard granted && error == nil else {
                    Logger.i("Contact import permission granted, importing contacts")
                    completion(.permissionDeniedExplicitly)
                    return
                }
                
                mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
                
                operationQueue.addOperation { [self] in
                    Logger.i("Contact import permission granted, importing contacts")
                    _importContacts(contactStore) { result in
                        defer {
                            mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
                        }
                        
                        completion(result)
                    }
                }
            }
        case .denied,
             .restricted:
            Logger.v("Contact import permission not granted [status=\(authorizationStatus.rawValue)]")
            completion(.permissionDenied)
        @unknown default:
            Logger.e("Contact import permission status unknown")
            completion(.permissionDenied)
        }
    }
    
    private func _importContacts(_ store: CNContactStore, completion: ImportCompletion) {
        let keys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey,
            CNContactImageDataAvailableKey
        ]
        
        let fetchRequest = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])
        
        do {
            var contacts = [Contact]()
            
            try store.enumerateContacts(with: fetchRequest) { contact, _ in
                contacts.append(Contact(contact))
            }
            
            Logger.i("Contact import succeeded")
            completion(.success(contacts: contacts))
        } catch {
            Logger.e("Contact import failed [error=\(error)]")
            completion(.failed)
        }
    }
    
    enum Result {
        case success(contacts: [Contact])
        case permissionDenied
        case permissionDeniedExplicitly
        case failed
    }
}

private extension Contact {
    
    init(_ contact: CNContact) {
        self.identifier = contact.identifier
        self.firstName = contact.givenName
        self.lastName = contact.familyName
        self.phoneNumbers = contact.phoneNumbers.map { LabeledValue(label: $0.label ?? "", value: $0.value.stringValue) }
        self.emailAddresses = contact.emailAddresses.map { LabeledValue(label: $0.label ?? "", value: $0.value as String) }
        self.imageUrl = nil // TODO: Do something here
        self.thumbnailUrl = nil // TODO: Do something here
        self.flags = .imported
    }
}
