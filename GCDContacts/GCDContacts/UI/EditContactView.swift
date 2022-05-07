//
//  EditContactView.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 14/04/2022.
//

import SwiftUI


struct EditContactView: View {
    
    private let navigationTitle = "Edit contact"
    
    @ObservedObject var viewModel: ContactViewModel
    
    @State private var lastName = ""
    @State private var firstName = ""
    @State private var phoneNumbers = [LabeledUIValue]()
    @State private var emailAddresses = [LabeledUIValue]()
    @State private var labelPickerId: UUID?
    
    @Environment(\.dismiss) private var dismiss
    
    var doesContactExist: Bool {
        viewModel.contact != nil
    }
    
    var body: some View {
        VStack {
            if doesContactExist {
                GeometryReader { geometry in
                    List {
                        ContactComponents.buildFirstNameTextField($firstName)
                        ContactComponents.buildLastNameTextField($lastName)
                        
                        ContactComponents.buildPhoneNumbersSection(geometry, labelPickerId: $labelPickerId, phoneNumbers: $phoneNumbers)
                        ContactComponents.buildEmailAddressesSection(geometry, labelPickerId: $labelPickerId, emailAddresses: $emailAddresses)
                        
                        buildDeleteButton()
                    }
                    .environment(\.editMode, .constant(.active))
                    .listStyle(.grouped)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem {
                buildSaveButton()
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                prepareEditableData()
            }
        }
    }
    
    private func buildSaveButton() -> some View {
        Button {
            saveContact()
        } label: {
            Text("Save")
        }
        .disabled(!doesContactExist)
    }
    
    private func buildDeleteButton() -> some View {
        Section {
            Button("Delete this contact") {
                deleteContact()
            }
            .foregroundColor(Color.red)
        }
        .buttonStyle(.plain)
    }
    
    /**
     
     MEANINGFUL LINES OF CODE: 20
     
     TOTAL DEPENDENCY DEGREE: 18
     
     */
    
    // [dd: 9]
    private func saveContact() {
        guard let oldContact = viewModel.contact else { // [rd: { init viewModel.contact } (1)]
            return
        }
        
        let contact = Contact(identifier: oldContact.identifier,
                              firstName: firstName,
                              lastName: lastName,
                              // closure #1: [dd: 1]; closure #2: [dd: 2]
                              phoneNumbers: phoneNumbers.filter { !$0.value.isEmpty /* [rd: { init $0.value } (1)] */ }.map { LabeledValue(label: $0.label, value: $0.value) /* [rd: { init $0.label, $0.value } (2)] */ },
                              // closure #1: [dd: 1]; closure #2: [dd: 2]
                              emailAddresses: emailAddresses.filter { !$0.value.isEmpty /* [rd: { init $0.value } (1)] */}.map { LabeledValue(label: $0.label, value: $0.value) /* [rd: { init $0.label, $0.value } (2)] */ },
                              flags: oldContact.flags) // [rd: { init oldContact.identifier, init firstName, init lastName, init phoneNumbers, init emailAddresses, init oldContact.flags } (6)]
        
        ContactStore.shared.storeContact(contact) // [rd: { init ContactStore.shared, let contact } (2)]
        
        dismiss()
    } // [lines: 13]
    
    // [dd: 3]
    private func deleteContact() {
        guard let identifier = viewModel.contact?.identifier else { // [rd: { init viewModel.contact?.identifier } (1)]
            return
        }
        
        ContactStore.shared.deleteContact(identifier) // [rd: { init ContactStore.shared, let identifier } (2)]
        
        dismiss()
    } // [lines: 20]
    
    private func prepareEditableData() {
        guard let contact = viewModel.contact else {
            return
        }
        
        firstName = contact.firstName
        lastName = contact.lastName
        phoneNumbers = contact.phoneNumbers.map { LabeledUIValue(label: $0.label, value: $0.value) }
        emailAddresses = contact.emailAddresses.map { LabeledUIValue(label: $0.label, value: $0.value) }
    }
}

struct EditContactView_Previews: PreviewProvider {
    static var previews: some View {
        EditContactView(viewModel: ContactViewModel.shared(for: Contact(identifier: "Test", firstName: "First name", lastName: "Last name", phoneNumbers: [LabeledValue(label: "mobile", value: "+1 (111)-1111-111")], emailAddresses: [], flags: [])))
    }
}
