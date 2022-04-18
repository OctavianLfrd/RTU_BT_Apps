//
//  LabeledUIValue.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 18/04/2022.
//

import Foundation


struct LabeledUIValue: Hashable, Identifiable {
    let id = UUID()
    var label: String
    var value: String
}
