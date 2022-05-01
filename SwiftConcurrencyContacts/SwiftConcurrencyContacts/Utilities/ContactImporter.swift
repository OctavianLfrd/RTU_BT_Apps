//
//  ContactImporter.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 30/04/2022.
//

import Foundation
import Contacts
import MetricKit


class ContactImporter {
    
    static let shared = ContactImporter()
    
    private init() {
    }
    
    func importContacts() async throws -> [Contact] {
        Logger.i("Contact import started")
        
        let authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        
        switch authorizationStatus {
        case .authorized:
            Logger.i("Contact import authorized, proceeding")
            
            mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
            
            defer {
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
            }
            
            return try await _importContacts(CNContactStore())
        case .notDetermined:
            Logger.i("Contact import authorization status notDetermined, requesting permission")
            
            let contactStore = CNContactStore()
            
            guard (try? await contactStore.requestAccess(for: .contacts)) == true else {
                Logger.v("Contact permission denied")
                throw Error.permissionDeniedExplicitly
            }
            
            mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
            
            defer {
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
            }
            
            Logger.i("Contact import permission granted, importing contacts")
            
            return try await _importContacts(contactStore)
        case .denied,
             .restricted:
            Logger.v("Contact import permission not granted [status=\(authorizationStatus.rawValue)]")
            throw Error.permissionDenied
        @unknown default:
            Logger.e("Contact import permission status unknown")
            throw Error.permissionDenied
        }
    }
    
    private func _importContacts(_ store: CNContactStore) async throws -> [Contact] {
        return try await withUnsafeThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
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
                    continuation.resume(returning: contacts)
                } catch {
                    Logger.e("Contact import failed [error=\(error)]")
                    continuation.resume(throwing: Error.failed)
                }
            }
        }
    }
    
    enum Error : Swift.Error {
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
