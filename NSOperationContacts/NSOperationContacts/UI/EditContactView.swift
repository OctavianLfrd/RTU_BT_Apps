//
//  EditContactView.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 25/04/2022.
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
            OperationQueue.main.addOperation {
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
     
     */
    
    private func saveContact() {
        guard let oldContact = viewModel.contact else {
            return
        }
        
        let contact = Contact(identifier: oldContact.identifier,
                              firstName: firstName,
                              lastName: lastName,
                              phoneNumbers: phoneNumbers.filter { !$0.value.isEmpty }.map { LabeledValue(label: $0.label, value: $0.value) },
                              emailAddresses: emailAddresses.filter { !$0.value.isEmpty }.map { LabeledValue(label: $0.label, value: $0.value) },
                              flags: oldContact.flags)
        
        ContactStore.shared.storeContact(contact)
        
        dismiss()
    } // [lines: 13]
    
    private func deleteContact() {
        guard let identifier = viewModel.contact?.identifier else {
            return
        }
        
        ContactStore.shared.deleteContact(identifier)
        
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
