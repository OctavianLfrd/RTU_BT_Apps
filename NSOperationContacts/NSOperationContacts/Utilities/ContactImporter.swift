//
//  ContactImporter.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 121
 
 TOTAL DEPENDENCY DEGREE: 73
 
 */

import Foundation
import Contacts
import MetricKit // [lines: 3]


class ContactImporter { // [lines: 4]
    
    typealias ImportCompletion = (Result) -> Void // [lines: 5]
    
    static let shared = ContactImporter() // [lines: 6]
    
    private let operationQueue: OperationQueue
    private let underlyingQueue: DispatchQueue // [lines: 8]
    
    // [dd: 1]
    private init() {
        underlyingQueue = DispatchQueue(label: "ContactImporter.Queue", qos: .userInitiated, target: .global(qos: .userInitiated))
        operationQueue = OperationQueue()
        operationQueue.underlyingQueue = underlyingQueue // [rd: { init underlyingQueue } (1)]
        operationQueue.maxConcurrentOperationCount = 1
    } // [lines: 14]
    
    // [dd: 15]
    func importContacts(completion: @escaping ImportCompletion) {
        Logger.i("Contact import started") // [rd: { init Logger } (1)]
        
        let authorizationStatus = CNContactStore.authorizationStatus(for: .contacts) // [rd: { init CNContactStore } (1)]
        
        switch authorizationStatus { // [rd: { let authorizationStatus } (1)]
        case .authorized:
            Logger.i("Contact import authorized, proceeding") // [rd: { init Logger } (1)]
            
            mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
            
            // closure: [dd: 1]
            operationQueue.addOperation { [self] in // [rd: { init operationQueue, init completion } (2)]
                // closure: [dd: 2]
                _importContacts(CNContactStore()) { result in // [rd: { init completion } (1)]
                    defer {
                        mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
                    }
                    
                    completion(result) // [rd: { init completion, init result } (2)]
                }
            }
        case .notDetermined:
            Logger.i("Contact import authorization status notDetermined, requesting permission") // [rd: { init Logger } (1)]
            
            let contactStore = CNContactStore()
            
            // closure: [dd: 9]
            contactStore.requestAccess(for: .contacts) { [self] granted, error in // [rd: { let contactStore, init completion } (2)]
                guard granted && error == nil else { // [rd: { init granted, init error } (2)]
                    Logger.v("Contact import permission denied [granted=\(granted), error=\(String(describing: error))]") // [rd: { init Logger, init granted, init error } (3)]
                    completion(.permissionDeniedExplicitly) // [rd: { init completion } (1)]
                    return
                }
                
                mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
                
                // closure: [dd: 3]
                operationQueue.addOperation { [self] in // [rd: { init operationQueue, init completion, init contactStore } (3)]
                    Logger.i("Contact import permission granted, importing contacts") // [rd: { init Logger } (1)]
                    
                    // closure: [dd: 2]
                    _importContacts(contactStore) { result in // [rd: { init contactStore, init completion } (2)]
                        defer {
                            mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactImportSignpostName)
                        }
                        
                        completion(result) // [rd: { init completion, init result } (2)]
                    }
                }
            }
        case .denied,
             .restricted:
            Logger.v("Contact import permission not granted [status=\(authorizationStatus.rawValue)]") // [rd: { init Logger, (let authorizationStatus).rawValue } (2)]
            completion(.permissionDenied) // [rd: { init completion } (1)]
        @unknown default:
            Logger.e("Contact import permission status unknown") // [rd: { init Logger } (1)]
            completion(.permissionDenied) // [rd: { init completion } (1)]
        }
    } // [lines: 50]
    
    // [dd: 15]
    private func _importContacts(_ store: CNContactStore, completion: ImportCompletion) {
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
            completion(.success(contacts: contacts)) // [rd: { init completion, var contacts, try store.enumerateContacts } (3)]
        } catch {
            Logger.e("Contact import failed [error=\(error)]") // [rd: { init Logger, init error } (2)]
            completion(.failed) // [rd: { init completion } (1)]
        }
    } // [lines: 72]
    
    enum Result {
        case success(contacts: [Contact])
        case permissionDenied
        case permissionDeniedExplicitly
        case failed
    } // [lines: 78]
} // [lines: 79]

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
} // [lines: 121]
