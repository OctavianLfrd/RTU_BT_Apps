//
//  ContactViewModel.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 14/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 42
 
 TOTAL DEPENDENCY DEGREE: 24
 
 */

import Foundation // [lines: 1]


class ContactViewModel : ObservableObject { // [lines: 2]
    
    private static var viewModels: [String : WeakWrapper] = [:] // [lines: 3]
    
    @Published private(set) var contact: Contact?
    private var contactIdentifier: String? // [lines: 5]
    
    // [dd: 13]
    static func shared(for contact: Contact) -> ContactViewModel {
        for id in viewModels.keys.reversed() {
            if viewModels[id]!.model == nil { // [rd: { init viewModels, (for id) } (2)]
                viewModels.removeValue(forKey: id) // [rd: { init viewModels, viewModels.removeValue(...), id } (3)]
            }
        }
        
        let model = viewModels[contact.identifier]?.model ?? ContactViewModel(contact) // [rd: { init viewModels, viewModels.removeValue(...), init contact.identifier, init contact } (4)]
        
        if !viewModels.keys.contains(contact.identifier) { // [rd: { init viewModels.keys, init contact.identifier } (2)]
            viewModels[contact.identifier] = WeakWrapper(model) // [rd: { let model } (1)]
        }
        
        return model // [rd: { let model } (1)]
    } // [lines: 17]
    
    // [dd: 3]
    private init(_ contact: Contact) {
        self.contact = contact // [rd: { init contact } (1)]
        self.contactIdentifier = contact.identifier // [rd: { init contact.identifier } (1)]
        
        ContactStore.shared.addListener(self) // [rd: { init ContactStore.shared } (1)]
    } // [lines: 22]
    
    // [dd: 1]
    deinit {
        ContactStore.shared.removeListener(self) // [rd: { init ContactStore.shared } (1)]
    } // [lines: 25]
    
    private struct WeakWrapper {
        weak var model: ContactViewModel?
        
        // [dd: 1]
        init(_ model: ContactViewModel) {
            self.model = model // [rd: { init model } (1)]
        }
    } // [lines: 31]
} // [lines: 32]

extension ContactViewModel : ContactStoreListener {
    // [dd: 2]
    func contactStore(_ contactStore: ContactStore, didUpdate contacts: [Contact]) {
        // closure: [dd: 2]
        DispatchQueue.main.async { [weak self] in // [rd: { init contacts, init DispatchQueue.main } (2)]
            guard let self = self else { // [rd: { weak self } (1)]
                return
            }
            
            // closure: [dd: 2]
            self.contact = contacts.first(where: { $0.identifier == self.contactIdentifier } /* [rd: { (let self).contactIdentifier, init $0.identifier } (2)] */ ) // [rd: { init contacts } (1)]
        }
    }
} // [lines: 42]
