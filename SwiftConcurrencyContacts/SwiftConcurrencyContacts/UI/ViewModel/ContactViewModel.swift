//
//  ContactViewModel.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 01/05/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 38
 
 TOTAL DEPENDENCY DEGREE: 22
 
 */

import Foundation // [lines: 1]


@MainActor
class ContactViewModel : ObservableObject { // [lines: 3]
    
    private static var viewModels: [String : WeakWrapper] = [:] // [lines: 4]
    
    @Published private(set) var contact: Contact?
    private var contactIdentifier: String? // [lines: 6]
    
    // [dd: 14]
    static func shared(for contact: Contact) -> ContactViewModel {
        for id in viewModels.keys.reversed() { // [rd: { init viewModels.keys } (1)]
            if viewModels[id]!.model == nil { // [rd: { init viewModels, (for id) } (2)]
                viewModels.removeValue(forKey: id) // [rd: { init viewModels, viewModels.removeValue(...), id } (3)]
            }
        }
        
        let model = viewModels[contact.identifier]?.model ?? ContactViewModel(contact) // [rd: { init viewModels, viewModels.removeValue(...), init contact.identifier, init contact } (4)]
        
        if !viewModels.keys.contains(contact.identifier) { // [rd: { init viewModels.keys, init contact.identifier } (2)]
            viewModels[contact.identifier] = WeakWrapper(model) // [rd: { let model } (1)]
        }
        
        return model // [rd: { let model } (1)]
    } // [lines: 18]
    
    // [dd: 2]
    private init(_ contact: Contact) {
        self.contact = contact // [rd: { init contact } (1)]
        self.contactIdentifier = contact.identifier // [rd: { init contact.identifier } (1)]
        
        // closure: [dd: 1]
        Task(priority: .high) {
            await ContactStore.shared.addListener(self) // [rd: { init ContactStore.shared } (1)]
        }
    } // [lines: 25]
    
    private struct WeakWrapper {
        weak var model: ContactViewModel?
        
        // [dd: 1]
        init(_ model: ContactViewModel) {
            self.model = model // [rd: { init model } (1)]
        }
    } // [lines: 31]
}

extension ContactViewModel : ContactStoreListener {
    
    // [dd: 1]
    func contactStore(_ contactStore: ContactStore, didUpdate contacts: [Contact]) {
        // closure: [dd: 1]
        Task { // [rd: { init contacts } (1)]
            // closure: [dd: 2]
            self.contact = contacts.first(where: { $0.identifier == contactIdentifier } /* [rd: { init $0.identifier, init contactIdentifier } (2)] */ ) // [rd: { init contacts } (1)]
        }
    }
} // [lines: 38]
