//
//  ContactComponents.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 01/05/2022.
//

import Foundation
import SwiftUI


struct ContactComponents {
    
    static func buildFirstNameTextField(_ firstName: Binding<String>) -> some View {
        TextField("First name", text: firstName)
    }
    
    static func buildLastNameTextField(_ lastName: Binding<String>) -> some View {
        TextField("Last name", text: lastName)
    }
    
    static func buildPhoneNumbersSection(_ geometry: GeometryProxy, labelPickerId: Binding<UUID?>, phoneNumbers: Binding<[LabeledUIValue]>) -> some View {
        Section {
            ForEach(phoneNumbers) { phoneNumber in
                buildLabeledTextField(geometry, hint: "Phone number", value: phoneNumber, labelPickerId: labelPickerId, labels: Contact.phoneNumberLabels)
            }
            .onDelete { offsets in
                phoneNumbers.wrappedValue.remove(atOffsets: offsets)
            }
            
            buildAddButton("add phone number") {
                phoneNumbers.wrappedValue.append(LabeledUIValue(label: Contact.phoneNumberLabelMobile, value: ""))
            }
        }
    }
    
    static func buildEmailAddressesSection(_ geometry: GeometryProxy, labelPickerId: Binding<UUID?>, emailAddresses: Binding<[LabeledUIValue]>) -> some View {
        Section {
            ForEach(emailAddresses) { emailAddress in
                buildLabeledTextField(geometry, hint: "Email", value: emailAddress, labelPickerId: labelPickerId, labels: Contact.emailLabels)
            }
            .onDelete { offsets in
                emailAddresses.wrappedValue.remove(atOffsets: offsets)
            }
            
            buildAddButton("add email") {
                emailAddresses.wrappedValue.append(LabeledUIValue(label: Contact.emailLabelWork, value: ""))
            }
        }
    }
    
    static func buildLabeledTextField(_ geometry: GeometryProxy, hint: String, value: Binding<LabeledUIValue>, labelPickerId: Binding<UUID?>, labels: @escaping @autoclosure () -> [String]) -> some View {
        HStack(alignment: .center) {
            buildLabeledButton(geometry, value: value, labelPickerId: labelPickerId, labels: Contact.emailLabels)
            TextField(hint, text: value.value)
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
    
    static func buildLabeledButton(_ geometry: GeometryProxy, value: Binding<LabeledUIValue>, labelPickerId: Binding<UUID?>, labels: @escaping @autoclosure () -> [String]) -> some View {
        HStack {
            Text(value.wrappedValue.label)
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
            labelPickerId.wrappedValue = value.id
        }
        .sheet(isPresented: Binding(get: {
            labelPickerId.wrappedValue == value.id
        }, set: {
            if !$0 {
                labelPickerId.wrappedValue = nil
            }
        }), onDismiss: nil) {
            LabelPickerView(labels: labels(), selectedLabel: value.label)
        }
    }
    
    static func buildAddButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.green)
                    .frame(width: 18, height: 18, alignment: .center)
                    .padding(EdgeInsets(top: 0, leading: 1, bottom: 0, trailing: 10))
                Text(title)
            }
        }
        .buttonStyle(.plain)
    }
}
