//
//  ContactImporter.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 13/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 116
 
 */

import Foundation
import Contacts
import MetricKit // [lines: 3]


class ContactImporter { // [lines: 4]
    
    typealias ImportCompletion = (Result) -> Void // [lines: 5]
    
    static let shared = ContactImporter() // [lines: 6]
    
    private let queue = DispatchQueue(label: "ContactImporter.Queue", qos: .userInitiated, target: .global(qos: .userInitiated)) // [lines: 7]
    
    private init() {
    } // [lines: 9]
    
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
    } // [lines: 45]
    
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
                let appContact = Contact(contact)
                contacts.append(appContact)
                Logger.v("Imported contact=\(appContact)")
            }
            
            Logger.i("Contact import succeeded")
            completion(.success(contacts: contacts))
        } catch {
            Logger.e("Contact import failed [error=\(error)]")
            completion(.failed)
        }
    } // [lines: 67]
    
    enum Result {
        case success(contacts: [Contact])
        case permissionDenied
        case permissionDeniedExplicitly
        case failed
    } // [lines: 73]
} // [lines: 74]

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
} // [lines: 116]
