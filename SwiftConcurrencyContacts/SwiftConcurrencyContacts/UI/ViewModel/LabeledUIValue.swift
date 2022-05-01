//
//  LabeledUIValue.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 01/05/2022.
//

import Foundation


struct LabeledUIValue : Hashable, Identifiable {
    let id = UUID()
    var label: String
    var value: String
}
