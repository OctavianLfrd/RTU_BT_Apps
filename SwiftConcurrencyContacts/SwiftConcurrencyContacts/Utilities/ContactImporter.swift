//
//  ContactImporter.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 30/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 106
 
 TOTAL DEPENDENCY DEGREE: 55
 
 */

import Foundation
import Contacts
import MetricKit // [lines: 3]


class ContactImporter { // [lines: 4]
    
    static let shared = ContactImporter() // [lines: 5]
    
    private init() {
    } // [lines: 7]
    
    // [dd: 12]
    func importContacts() async throws -> [Contact] {
        Logger.i("Contact import started") // [rd: { init Logger } (1)]
        
        let authorizationStatus = CNContactStore.authorizationStatus(for: .contacts) // [rd: { init CNContactStore } (1)]
        
        switch authorizationStatus { // [rd: { let authorizationStatus } (1)]
        case .authorized:
            Logger.i("Contact import authorized, proceeding") // [rd: { init Logger } (1)]
            
            mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
            
            defer {
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
            }
            
            return try await _importContacts(CNContactStore())
        case .notDetermined:
            Logger.i("Contact import authorization status notDetermined, requesting permission") // [rd: { init Logger } (1)]
            
            let contactStore = CNContactStore()
            
            guard (try? await contactStore.requestAccess(for: .contacts)) == true else { // [rd: { let contactStore } (1)]
                Logger.v("Contact permission denied") // [rd: { init Logger } (1)]
                throw Error.permissionDeniedExplicitly
            }
            
            mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
            
            defer {
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
            }
            
            Logger.i("Contact import permission granted, importing contacts") // [rd: { init Logger } (1)]
            
            return try await _importContacts(contactStore) // [rd: { init contactStore } (1)]
        case .denied,
             .restricted:
            Logger.v("Contact import permission not granted [status=\(authorizationStatus.rawValue)]") // [rd: { init Logger, (let authorizationStatus).rawValue } (2)]
            throw Error.permissionDenied
        @unknown default:
            Logger.e("Contact import permission status unknown") // [rd: { init Logger } (1)]
            throw Error.permissionDenied
        }
    } // [lines: 32]
    
    // [dd: 1]
    private func _importContacts(_ store: CNContactStore) async throws -> [Contact] {
        // closure: [dd: 2]
        return try await withUnsafeThrowingContinuation { continuation in // [rd: { init store } (1)]
            // closure: [dd: 15]
            DispatchQueue.global(qos: .userInitiated).async { // [rd: { init store, init continuation } (2)]
                let keys = [
                    CNContactGivenNameKey,
                    CNContactFamilyNameKey,
                    CNContactEmailAddressesKey,
                    CNContactPhoneNumbersKey
                ] // [rd: { init CNContactGivenNameKey, ... } (4)]
                
                let fetchRequest = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor]) // [rd: { let keys } (1)]
                
                do {
                    var contacts = [Contact]()
                    
                    // closure: [dd: 6]
                    try store.enumerateContacts(with: fetchRequest) { contact, _ in // [rd: { init store, let fetchRequest, var contacts } (3)]
                        let appContact = Contact(contact) // [rd: { init contact } (1)]
                        contacts.append(appContact) // [rd: { var contacts, try store.enumerateContacts, let appContact } (3)]
                        Logger.v("Imported contact=\(appContact)") // [rd: { init Logger, let appContact } (2)]
                    }
                    
                    Logger.i("Contact import succeeded") // [rd: { init Logger } (1)]
                    continuation.resume(returning: contacts) // [rd: { init continuation, var contacts, try store.enumerateContacts } (3)]
                } catch {
                    Logger.e("Contact import failed [error=\(error)]") // [rd: { init Logger, init error } (2)]
                    continuation.resume(throwing: Error.failed) // [rd: { init continuation } (1)]
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
    
    // [dd: 5]
    init(_ contact: CNContact) {
        self.identifier = contact.identifier // [rd: { init contact.identifier } (1)]
        self.firstName = contact.givenName // [rd: { init contact.givenName } (1)]
        self.lastName = contact.familyName // [rd: { init contact.familyName } (1)]
        // closure: [dd: 2]
        self.phoneNumbers = contact.phoneNumbers.map { LabeledValue(label: Self.mapPhoneNumberLabel($0.label), value: $0.value.stringValue) /* [rd: { init $0.label, init $0.value } (2)] */ } // [rd: { contact.phoneNumbers } (1)]
        // closure: [dd: 2]
        self.emailAddresses = contact.emailAddresses.map { LabeledValue(label: Self.mapEmailLabel($0.label), value: $0.value as String) /* [rd: { init $0.label, init $0.value } (2)] */ } // [rd: { contact.emailAddresses } (1)]
        self.flags = .imported
    }
    
    // [dd: 5]
    private static func mapPhoneNumberLabel(_ cnLabel: String?) -> String {
        guard let cnLabel = cnLabel else { // [rd: { init cnLabel } (1)]
            return Contact.phoneNumberLabelOther // [rd: { init Contact.phoneNumberLabelOther } (1)]
        }

        return Self.phoneNumberLabelMap[cnLabel] ?? Contact.phoneNumberLabelOther // [rd: { init Self.phoneNumberLabelMap, let cnLabel, Contact.phoneNumberLabelOther } (3)]
    }
    
    // [dd: 5]
    private static func mapEmailLabel(_ cnLabel: String?) -> String {
        guard let cnLabel = cnLabel else { // [rd: { init cnLabel } (1)]
            return Contact.emailLabelOther // [rd: { init Contact.emailLabelOther } (1)]
        }

        return Self.emailLabelMap[cnLabel] ?? Contact.emailLabelOther // [rd: { init Self.emailLabelMap, let cnLabel, Contact.emailLabelOther } (3)]
    }
} // [lines: 106]
