//
//  AddContactView.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 14/04/2022.
//

import SwiftUI

struct AddContactView: View {
    
    private let navigationTitle = "Add contact"
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phoneNumbers = [ LabeledUIValue(label: Contact.phoneNumberLabelMobile, value: "") ]
    @State private var emailAddresses = [ LabeledUIValue(label: Contact.emailLabelWork, value: "") ]
    @State private var labelPickerId: UUID?
    
    @Environment(\.dismiss) private var dismiss
    
    private var readyToSave: Bool {
        !firstName.isEmpty || !lastName.isEmpty || phoneNumbers.contains(where: { !$0.value.isEmpty }) || emailAddresses.contains(where: { !$0.value.isEmpty })
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            GeometryReader { geometry in
                List {
                    ContactComponents.buildFirstNameTextField($firstName)
                    ContactComponents.buildLastNameTextField($lastName)
                    ContactComponents.buildPhoneNumbersSection(geometry, labelPickerId: $labelPickerId, phoneNumbers: $phoneNumbers)
                    ContactComponents.buildEmailAddressesSection(geometry, labelPickerId: $labelPickerId, emailAddresses: $emailAddresses)
                }
                .environment(\.editMode, .constant(.active))
                .listStyle(.grouped)
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem {
                buildSaveButton()
            }
        }
    }
    
    private func buildSaveButton() -> some View {
        Button {
            saveContact()
        } label: {
            Text("Save")
        }
        .disabled(!readyToSave)
    }
    
    private func saveContact() {
        let contact = Contact(identifier: UUID().uuidString,
                              firstName: firstName,
                              lastName: lastName,
                              phoneNumbers: phoneNumbers.filter { !$0.value.isEmpty }.map { LabeledValue(label: $0.label, value: $0.value) },
                              emailAddresses: emailAddresses.filter { !$0.value.isEmpty }.map { LabeledValue(label: $0.label, value: $0.value) },
                              flags: [])
        
        ContactStore.shared.storeContact(contact)
        
        dismiss()
    }
}

struct AddContactView_Previews: PreviewProvider {
    static var previews: some View {
        AddContactView()
    }
}
