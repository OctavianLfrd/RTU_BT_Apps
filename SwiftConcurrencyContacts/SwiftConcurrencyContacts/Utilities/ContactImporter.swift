//
//  ContactImporter.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 30/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 106
 
 */

import Foundation
import Contacts
import MetricKit // [lines: 3]


class ContactImporter { // [lines: 4]
    
    static let shared = ContactImporter() // [lines: 5]
    
    private init() {
    } // [lines: 7]
    
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
    } // [lines: 32]
    
    private func _importContacts(_ store: CNContactStore) async throws -> [Contact] {
        return try await withUnsafeThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
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
                        let appContact = Contact(contact)
                        contacts.append(appContact)
                        Logger.v("Imported contact=\(appContact)")
                    }
                    
                    Logger.i("Contact import succeeded")
                    continuation.resume(returning: contacts)
                } catch {
                    Logger.e("Contact import failed [error=\(error)]")
                    continuation.resume(throwing: Error.failed)
                }
            }
        }
    } // [lines: 58]
    
    enum Error : Swift.Error {
        case permissionDenied
        case permissionDeniedExplicitly
        case failed
    } // [lines: 63]
} // [lines: 64]

private extension Contact {
    
    private static let phoneNumberLabelMap: [String : String] = [
        CNLabelPhoneNumberMobile : Contact.phoneNumberLabelMobile,
        CNLabelHome : Contact.phoneNumberLabelHome,
        CNLabelWork : Contact.phoneNumberLabelWork,
        CNLabelSchool : Contact.phoneNumberLabelSchool,
        CNLabelPhoneNumberiPhone : Contact.phoneNumberLabeliPhone,
        CNLabelPhoneNumberAppleWatch : Contact.phoneNumberLabelAppleWatch,
        CNLabelPhoneNumberMain : Contact.phoneNumberLabelMain,
        CNLabelPhoneNumberHomeFax : Contact.phoneNumberLabelHomeFax,
        CNLabelPhoneNumberWorkFax : Contact.phoneNumberLabelWorkFax,
        CNLabelPhoneNumberPager : Contact.phoneNumberLabelPager,
        CNLabelOther : Contact.phoneNumberLabelOther
    ]
    
    private static let emailLabelMap: [String : String] = [
        CNLabelHome : Contact.emailLabelHome,
        CNLabelWork : Contact.emailLabelWork,
        CNLabelSchool : Contact.emailLabelSchool,
        CNLabelEmailiCloud : Contact.emailLabeliCloud,
        CNLabelOther : Contact.emailLabelOther
    ]
    
    init(_ contact: CNContact) {
        self.identifier = contact.identifier
        self.firstName = contact.givenName
        self.lastName = contact.familyName
        self.phoneNumbers = contact.phoneNumbers.map { LabeledValue(label: Self.mapPhoneNumberLabel($0.label), value: $0.value.stringValue) }
        self.emailAddresses = contact.emailAddresses.map { LabeledValue(label: Self.mapEmailLabel($0.label), value: $0.value as String) }
        self.flags = .imported
    }
    
    private static func mapPhoneNumberLabel(_ cnLabel: String?) -> String {
        guard let cnLabel = cnLabel else {
            return Contact.phoneNumberLabelOther
        }

        return Self.phoneNumberLabelMap[cnLabel] ?? Contact.phoneNumberLabelOther
    }
    
    private static func mapEmailLabel(_ cnLabel: String?) -> String {
        guard let cnLabel = cnLabel else {
            return Contact.emailLabelOther
        }

        return Self.emailLabelMap[cnLabel] ?? Contact.emailLabelOther
    }
} // [lines: 106]
