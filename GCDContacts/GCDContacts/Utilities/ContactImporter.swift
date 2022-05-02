//
//  ContactImporter.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 13/04/2022.
//

import Foundation
import Contacts
import MetricKit


class ContactImporter {
    
    typealias ImportCompletion = (Result) -> Void
    
    static let shared = ContactImporter()
    
    private let queue = DispatchQueue(label: "ContactImporter.Queue", qos: .userInitiated, target: .global(qos: .userInitiated))
    
    private init() {
    }
    
    func importContacts(completion: @escaping ImportCompletion) {
        Logger.i("Contact import started")
        
        let authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        
        switch authorizationStatus {
        case .authorized:
            Logger.i("Contact import authorized, proceeding")
            
            mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
            
            queue.async { [self] in
                _importContacts(CNContactStore()) { result in
                    defer {
                        mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
                    }
                    
                    completion(result)
                }
            }
            break
        case .notDetermined:
            Logger.i("Contact import authorization status notDetermined, requesting permission")
            
            let contactStore = CNContactStore()
            contactStore.requestAccess(for: .contacts) { [self] granted, error in
                guard granted && error == nil else {
                    Logger.v("Contact import permission denied [granted=\(granted), error=\(String(describing: error))]")
                    completion(.permissionDeniedExplicitly)
                    return
                }
                
                mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
                
                queue.async { [self] in
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
            CNContactPhoneNumbersKey
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
        self.flags = .imported
    }
}
