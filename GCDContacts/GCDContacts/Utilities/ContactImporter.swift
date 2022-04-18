//
//  ContactImporter.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 13/04/2022.
//

import Foundation
import Contacts


class ContactImporter {
    
    typealias ImportCompletion = (Result) -> Void
    
    static let shared = ContactImporter()
    
    private let queue = DispatchQueue(label: "ContactImporter", qos: .userInteractive, target: .global(qos: .userInteractive))
    
    private init() {
    }
    
    func importContacts(completion: @escaping ImportCompletion) {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            queue.async { [self] in
                _importContacts(CNContactStore(), completion: completion)
            }
            break
        case .notDetermined:
            let contactStore = CNContactStore()
            contactStore.requestAccess(for: .contacts) { [self] granted, error in
                guard granted && error == nil else {
                    completion(.permissionDeniedExplicitly)
                    return
                }
                
                queue.async { [self] in
                    _importContacts(contactStore, completion: completion)
                }
            }
        case .denied,
             .restricted:
            completion(.permissionDenied)
        @unknown default:
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
            
            completion(.success(contacts: contacts))
        } catch {
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
