//
//  LabelPickerView.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 25/04/2022.
//

import SwiftUI

struct LabelPickerView: View {
    
    let labels: [String]
    @Binding var selectedLabel: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(labels, id: \.self) { label in
                    HStack {
                        Button(label) {
                            selectedLabel = label
                            dismiss()
                        }
                        if label == selectedLabel {
                            Spacer()
                            Image(systemName: "checkmark")
                                .renderingMode(.template)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select label")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LabelPickerView_Previews: PreviewProvider {
    static var previews: some View {
        LabelPickerView(labels: ["label1", "label2", "label3"], selectedLabel: Binding<String>(get: { "label1" }, set: { _ in }))
    }
}
