//
//  EditContactView.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 14/04/2022.
//

import SwiftUI
import Combine

struct EditContactView: View {
    
    @ObservedObject var viewModel: ContactViewModel
    
    @State private var lastName = ""
    @State private var firstName = ""
    @State private var phoneNumbers = [Labeled]()
    @State private var emailAddresses = [Labeled]()
    @State private var labelPickerId: UUID?
    
    @Environment(\.dismiss) var dismiss
    
    var doesContactExist: Bool {
        viewModel.contact != nil
    }
    
    var body: some View {
        VStack {
            if doesContactExist {
                GeometryReader { geometry in
                    List {
                        TextField("First name", text: $firstName)
                        TextField("Last name", text: $lastName)
                        
                        Section {
                            ForEach($phoneNumbers) { phoneNumber in
                                HStack(alignment: .center) {

                                    HStack {
                                        Text(phoneNumber.wrappedValue.label)
                                            .lineLimit(1)
                                        Image(systemName: "chevron.right")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(.gray)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 12, height: 12, alignment: .center)
                                    }
                                    .foregroundColor(Color.blue)
                                    .frame(minWidth: 0, maxWidth: geometry.size.width / 2, alignment: .leading)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .onTapGesture {
                                        labelPickerId = phoneNumber.id
                                    }
                                    .sheet(isPresented: Binding(get: {
                                        labelPickerId == phoneNumber.id
                                    }, set: {
                                        if !$0 {
                                            labelPickerId = nil
                                        }
                                    }), onDismiss: nil) {
                                        LabelPickerView(labels: Contact.phoneNumberLabels, selectedLabel: phoneNumber.label)
                                    }
                                    
                                    TextField("Phone number", text: phoneNumber.value)
                                }
                                .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .onDelete { offsets in
                                phoneNumbers.remove(atOffsets: offsets)
                            }
                            
                            Button {
                                phoneNumbers.append(Labeled(label: Contact.phoneNumberLabelMobile, value: ""))
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(.green)
                                        .frame(width: 18, height: 18, alignment: .center)
                                        .padding(EdgeInsets(top: 0, leading: 1, bottom: 0, trailing: 10))
                                    Text("add phone number")
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Section {
                            ForEach($emailAddresses) { emailAddress in

                                HStack(alignment: .center) {

                                    HStack {
                                        Text(emailAddress.wrappedValue.label)
                                            .lineLimit(1)
                                        Image(systemName: "chevron.right")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(.gray)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 12, height: 12, alignment: .center)
                                    }
                                    .foregroundColor(Color.blue)
                                    .frame(minWidth: 0, maxWidth: geometry.size.width / 2, alignment: .leading)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .onTapGesture {
                                        labelPickerId = emailAddress.id
                                    }
                                    .sheet(isPresented: Binding(get: {
                                        labelPickerId == emailAddress.id
                                    }, set: {
                                        if !$0 {
                                            labelPickerId = nil
                                        }
                                    }), onDismiss: nil) {
                                        LabelPickerView(labels: Contact.emailLabels, selectedLabel: emailAddress.label)
                                    }
                                    
                                    TextField("Email", text: emailAddress.value)
                                }
                                .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .onDelete { offsets in
                                emailAddresses.remove(atOffsets: offsets)
                            }
                            
                            Button {
                                emailAddresses.append(Labeled(label: Contact.phoneNumberLabelMobile, value: ""))
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(.green)
                                        .frame(width: 18, height: 18, alignment: .center)
                                        .padding(EdgeInsets(top: 0, leading: 1, bottom: 0, trailing: 10))
                                    Text("add email")
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Section {
                            Button("Delete this contact") {
                                guard let identifier = viewModel.contact?.identifier else {
                                    return
                                }
                                
                                ContactStore.shared.deleteContact(identifier)
                                
                                dismiss()
                            }
                            .foregroundColor(Color.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .environment(\.editMode, .constant(.active))
                    .listStyle(.grouped)
                }
            }
        }
        .navigationTitle("Edit contact")
        .toolbar {
            ToolbarItem {
                Button {
                    guard let oldContact = viewModel.contact else {
                        return
                    }
                    
                    let contact = Contact(identifier: oldContact.identifier,
                                          firstName: firstName,
                                          lastName: lastName,
                                          phoneNumbers: phoneNumbers.filter { !$0.value.isEmpty }.map { LabeledValue(label: $0.label, value: $0.value) },
                                          emailAddresses: emailAddresses.filter { !$0.value.isEmpty }.map { LabeledValue(label: $0.label, value: $0.value) },
                                          imageUrl: oldContact.imageUrl,
                                          thumbnailUrl: oldContact.thumbnailUrl,
                                          flags: oldContact.flags)
                    
                    ContactStore.shared.storeContact(contact)
                    
                    dismiss()
                } label: {
                    Text("Save")
                }
                .disabled(!doesContactExist)
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                guard let contact = viewModel.contact else {
                    return
                }
                
                firstName = contact.firstName
                lastName = contact.lastName
                phoneNumbers = contact.phoneNumbers.map { Labeled(label: $0.label, value: $0.value) }
                emailAddresses = contact.emailAddresses.map { Labeled(label: $0.label, value: $0.value) }
            }
        }
    }
    
    private struct Labeled: Hashable, Identifiable {
        let id = UUID()
        var label: String
        var value: String
    }
}

struct EditContactView_Previews: PreviewProvider {
    static var previews: some View {
        EditContactView(viewModel: ContactViewModel.shared(for: Contact(identifier: "Test", firstName: "First name", lastName: "Last name", phoneNumbers: [LabeledValue(label: "mobile", value: "+1 (111)-1111-111")], emailAddresses: [], imageUrl: nil, thumbnailUrl: nil, flags: [])))
    }
}
