//
//  LabeledUIValue.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 25/04/2022.
//

import Foundation


struct LabeledUIValue : Hashable, Identifiable {
    let id = UUID()
    var label: String
    var value: String
}
