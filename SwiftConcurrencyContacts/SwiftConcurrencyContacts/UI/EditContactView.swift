//
//  EditContactView.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 01/05/2022.
//

import SwiftUI
import MetricKit


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
        .task {
            prepareEditableData()
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
     
     MEANINGFUL LINES OF CODE: 24
     
     TOTAL DEPENDENCY DEGREE: 20
     
     */
    
    // [dd: 8]
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
        
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
        
        // closure: [dd: 2]
        Task(priority: .low) { // [rd: { let contact } (1)]
            await ContactStore.shared.storeContact(contact) // [rd: { init ContactStore.shared, let contact } (2)]
            mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
        }
        
        dismiss()
    } // [lines: 15]
    
    // [dd: 2]
    private func deleteContact() {
        guard let identifier = viewModel.contact?.identifier else { // [rd: { init viewModel.contact?.identifier } (1)]
            return
        }
        
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreDeleting)
        
        // [dd: 2]
        Task(priority: .low) { // [rd: { let identifier } (1)]
            await ContactStore.shared.deleteContact(identifier) // [rd: { init ContactStore.shared, init identifier } (2)]
            mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreDeleting)
        }
        
        dismiss()
    } // [lines: 24]
    
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
