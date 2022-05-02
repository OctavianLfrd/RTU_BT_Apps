//
//  ContactViewModel.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 01/05/2022.
//

import Foundation


@MainActor
class ContactViewModel : ObservableObject {
    
    private static var viewModels: [String : WeakWrapper] = [:]
    
    @Published private(set) var contact: Contact?
    private var contactIdentifier: String?
    
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
    }
    
    private init(_ contact: Contact) {
        self.contact = contact
        self.contactIdentifier = contact.identifier
        
        Task(priority: .high) {
            await ContactStore.shared.addListener(self)
        }
    }
    
    private struct WeakWrapper {
        weak var model: ContactViewModel?
        
        init(_ model: ContactViewModel) {
            self.model = model
        }
    }
}

extension ContactViewModel : ContactStoreListener {
    func contactStore(_ contactStore: ContactStore, didUpdate contacts: [Contact]) {
        Task {
            self.contact = contacts.first(where: { $0.identifier == contactIdentifier })
        }
    }
}
