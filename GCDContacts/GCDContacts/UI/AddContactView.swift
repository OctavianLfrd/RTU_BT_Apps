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
    @State private var phoneNumbers = [ Labeled(label: Contact.phoneNumberLabelMobile, value: "") ]
    @State private var emailAddresses = [ Labeled(label: Contact.emailLabelWork, value: "") ]
    @State private var labelPickerId: UUID?
    
    @Environment(\.dismiss) private var dismiss
    
    private var readyToSave: Bool {
        !firstName.isEmpty || !lastName.isEmpty || phoneNumbers.contains(where: { !$0.value.isEmpty }) || emailAddresses.contains(where: { !$0.value.isEmpty })
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            GeometryReader { geometry in
                List {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text:  $lastName)
                    
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

                }
                .environment(\.editMode, .constant(.active))
                .listStyle(.grouped)
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem {
                Button {
                    let contact = Contact(identifier: UUID().uuidString,
                                          firstName: firstName,
                                          lastName: lastName,
                                          phoneNumbers: phoneNumbers.filter { !$0.value.isEmpty }.map { LabeledValue(label: $0.label, value: $0.value) },
                                          emailAddresses: emailAddresses.filter { !$0.value.isEmpty }.map { LabeledValue(label: $0.label, value: $0.value) },
                                          imageUrl: nil,
                                          thumbnailUrl: nil,
                                          flags: [])
                    
                    ContactStore.shared.storeContact(contact)
                    dismiss()
                } label: {
                    Text("Save")
                }
                .disabled(!readyToSave)
            }
        }
    }
    
    private struct Labeled : Hashable, Identifiable {
        let id = UUID()
        var label: String
        var value: String
    }
}

struct AddContactView_Previews: PreviewProvider {
    static var previews: some View {
        AddContactView()
    }
}
