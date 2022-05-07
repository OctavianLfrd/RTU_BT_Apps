//
//  ContactViewModel.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 01/05/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 38
 
 */

import Foundation // [lines: 1]


@MainActor
class ContactViewModel : ObservableObject { // [lines: 3]
    
    private static var viewModels: [String : WeakWrapper] = [:] // [lines: 4]
    
    @Published private(set) var contact: Contact?
    private var contactIdentifier: String? // [lines: 6]
    
    static func shared(for contact: Contact) -> ContactViewModel {
        for id in viewModels.keys.reversed() {
            if viewModels[id]!.model == nil {
                viewModels.removeValue(forKey: id)
            }
        }
        
        let model = viewModels[contact.identifier]?.model ?? ContactViewModel(contact)
        
        if !viewModels.keys.contains(contact.identifier) {
            viewModels[contact.identifier] = WeakWrapper(model)
        }
        
        return model
    } // [lines: 18]
    
    private init(_ contact: Contact) {
        self.contact = contact
        self.contactIdentifier = contact.identifier
        
        Task(priority: .high) {
            await ContactStore.shared.addListener(self)
        }
    } // [lines: 25]
    
    private struct WeakWrapper {
        weak var model: ContactViewModel?
        
        init(_ model: ContactViewModel) {
            self.model = model
        }
    } // [lines: 31]
}

extension ContactViewModel : ContactStoreListener {
    func contactStore(_ contactStore: ContactStore, didUpdate contacts: [Contact]) {
        Task {
            self.contact = contacts.first(where: { $0.identifier == contactIdentifier })
        }
    }
} // [lines: 38]
