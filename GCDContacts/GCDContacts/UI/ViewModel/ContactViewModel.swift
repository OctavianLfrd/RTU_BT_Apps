//
//  ContactViewModel.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 14/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 42
 
 */

import Foundation // [lines: 1]


class ContactViewModel : ObservableObject { // [lines: 2]
    
    private static var viewModels: [String : WeakWrapper] = [:] // [lines: 3]
    
    @Published private(set) var contact: Contact?
    private var contactIdentifier: String? // [lines: 5]
    
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
    } // [lines: 17]
    
    private init(_ contact: Contact) {
        self.contact = contact
        self.contactIdentifier = contact.identifier
        
        ContactStore.shared.addListener(self)
    } // [lines: 22]
    
    deinit {
        ContactStore.shared.removeListener(self)
    } // [lines: 25]
    
    private struct WeakWrapper {
        weak var model: ContactViewModel?
        
        init(_ model: ContactViewModel) {
            self.model = model
        }
    } // [lines: 31]
} // [lines: 32]

extension ContactViewModel : ContactStoreListener {
    func contactStore(_ contactStore: ContactStore, didUpdate contacts: [Contact]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            
            self.contact = contacts.first(where: { $0.identifier == self.contactIdentifier })
        }
    }
} // [lines: 42]
