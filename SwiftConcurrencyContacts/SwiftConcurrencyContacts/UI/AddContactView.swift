//
//  AddContactView.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 01/05/2022.
//

import SwiftUI
import MetricKit

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
    
    /**
     
     MEANINGFUL LINES OF CODE: 12
     
     TOTAL DEPENDENCY DEGREE: 13
     
     */
    
    // [dd: 5]
    private func saveContact() {
        let contact = Contact(identifier: UUID().uuidString,
                              firstName: firstName,
                              lastName: lastName,
                              // closure #1: [dd: 1]; closure #2: [dd: 2]
                              phoneNumbers: phoneNumbers.filter { !$0.value.isEmpty /* [rd: { init $0.value } (1)] */}.map { LabeledValue(label: $0.label, value: $0.value) /* [rd: { init $0.label, $0.value } (2)] */},
                              // closure #1: [dd: 1]; closure #2: [dd: 2]
                              emailAddresses: emailAddresses.filter { !$0.value.isEmpty /* [rd: { init $0.value } (1)] */}.map { LabeledValue(label: $0.label, value: $0.value) /* [rd: { init $0.label, $0.value } (2)] */},
                              flags: []) // [rd: { init firstName, init lastName, init phoneNumbers, init emailAddresses } (4)]
        
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
        
        // closure: [dd: 2]
        Task(priority: .low) { // [rd: { let contact } (1)]
            await ContactStore.shared.storeContact(contact) // [rd: { init ContactStore.shared, init contact } (2)]
            mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
        }
        
        dismiss()
    } // [lines: 12]
}

struct AddContactView_Previews: PreviewProvider {
    static var previews: some View {
        AddContactView()
    }
}
