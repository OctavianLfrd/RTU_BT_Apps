//
//  ContactDetailsView.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 25/04/2022.
//

import SwiftUI


struct ContactDetailsView: View {
    
    @ObservedObject var viewModel: ContactViewModel
    
    private let navigationTitle = "Contact details"
    
    var body: some View {
        VStack {
            if let contact = viewModel.contact {
                List {
                    if !contact.firstName.isEmpty {
                        buildFirstName(contact)
                    }
                    if !contact.lastName.isEmpty {
                        buildLastName(contact)
                    }
                    if !contact.phoneNumbers.isEmpty {
                        buildPhoneNumbers(contact)
                    }
                    if !contact.emailAddresses.isEmpty {
                        buildEmailAddresses(contact)
                    }
                }
            } else {
                Text("Contact is unavailable")
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem {
                NavigationLink("Edit") {
                    EditContactView(viewModel: viewModel)
                }
            }
        }
    }
    
    func buildFirstName(_ contact: Contact) -> some View {
        Section("First name") {
            Text(contact.firstName)
        }
    }
    
    func buildLastName(_ contact: Contact) -> some View {
        Section("Last name") {
            Text(contact.lastName)
        }
    }
    
    func buildPhoneNumbers(_ contact: Contact) -> some View {
        Section("Phone numbers") {
            ForEach(contact.phoneNumbers) { phoneNumber in
                VStack(alignment: .leading) {
                    Text(!phoneNumber.label.isEmpty ? phoneNumber.label : "Other")
                    if let url = URL(string: "tel://\(phoneNumber.value)") {
                        Link(destination: url) {
                            Text(phoneNumber.value)
                        }
                    } else {
                        Text(phoneNumber.value)
                    }
                }
            }
        }
    }
    
    func buildEmailAddresses(_ contact: Contact) -> some View {
        Section("Emails") {
            ForEach(contact.emailAddresses) { emailAddress in
                VStack(alignment: .leading) {
                    Text(!emailAddress.label.isEmpty ? emailAddress.label : "Other")
                    if let url = URL(string: "mailto:\(emailAddress.value)") {
                        Link(destination: url) {
                            Text(emailAddress.value)
                        }
                    } else {
                        Text(emailAddress.value)
                    }
                }
            }
        }
    }
}

struct ContactDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        ContactDetailsView(viewModel: ContactViewModel.shared(for: Contact(identifier: "Test", firstName: "First name", lastName: "Last name", phoneNumbers: [LabeledValue(label: "mobile", value: "+1 (111)-1111-111")], emailAddresses: [], flags: [])))
    }
}
