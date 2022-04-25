//
//  LabeledValue.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

import Foundation


struct LabeledValue<L, V> {
    let label: L
    let value: V
}

extension LabeledValue : Equatable where L: Equatable, V: Equatable {
}

extension LabeledValue : Encodable where L: Encodable, V: Encodable {
}

extension LabeledValue : Decodable where L: Decodable, V: Decodable {
}

extension LabeledValue : Identifiable where L: Hashable, V: Hashable {
    typealias ID = V
    
    var id: V {
        value
    }
}
