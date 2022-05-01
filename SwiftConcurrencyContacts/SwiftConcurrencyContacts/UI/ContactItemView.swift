//
//  ContactItemView.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 01/05/2022.
//

import Foundation

import SwiftUI

struct ContactItemView : View {
    
    private let contact: Contact
    
    var contactDisplayName: String {
        if !contact.firstName.isEmpty && !contact.lastName.isEmpty {
            return "\(contact.firstName) \(contact.lastName)"
        } else if !contact.firstName.isEmpty {
            return contact.firstName
        } else if !contact.lastName.isEmpty {
            return contact.lastName
        } else if let phoneNumber = contact.phoneNumbers.first(where: { !$0.value.isEmpty }) {
            return phoneNumber.value
        } else if let email = contact.emailAddresses.first(where: { !$0.value.isEmpty }) {
            return email.value
        } else {
            return "Unnamed"
        }
    }
    
    init(_ contact: Contact) {
        self.contact = contact
    }
    
    var body: some View {
        Text(contactDisplayName)
    }
}
