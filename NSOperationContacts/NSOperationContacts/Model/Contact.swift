//
//  Contact.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

import Foundation

struct Contact {
    
    
    static let phoneNumberLabelMobile = "mobile"
    static let phoneNumberLabelHome = "home"
    static let phoneNumberLabelWork = "work"
    static let phoneNumberLabelSchool = "school"
    static let phoneNumberLabeliPhone = "iPhone"
    static let phoneNumberLabelAppleWatch = "Apple Watch"
    static let phoneNumberLabelMain = "main"
    static let phoneNumberLabelHomeFax = "home fax"
    static let phoneNumberLabelWorkFax = "work fax"
    static let phoneNumberLabelPager = "pager"
    static let phoneNumberLabelOther = "other"
    
    
    static let emailLabelHome = "home"
    static let emailLabelWork = "work"
    static let emailLabelSchool = "school"
    static let emailLabeliCloud = "iCloud"
    static let emailLabelOther = "other"
    
    static var phoneNumberLabels: [String] {
        [phoneNumberLabelMobile,
         phoneNumberLabelHome,
         phoneNumberLabelWork,
         phoneNumberLabelSchool,
         phoneNumberLabeliPhone,
         phoneNumberLabelAppleWatch,
         phoneNumberLabelMain,
         phoneNumberLabelHomeFax,
         phoneNumberLabelWorkFax,
         phoneNumberLabelPager,
         phoneNumberLabelOther]
    }
    
    static var emailLabels: [String] {
        [emailLabelHome,
         emailLabelWork,
         emailLabelSchool,
         emailLabeliCloud,
         emailLabelOther]
    }
    
    let identifier: String
    let firstName: String
    let lastName: String
    let phoneNumbers: [LabeledValue<String, String>]
    let emailAddresses: [LabeledValue<String, String>]
    let imageUrl: URL?
    let thumbnailUrl: URL?
    let flags: Flags
    
    struct Flags: OptionSet, Codable {
        let rawValue: OptionBits
        
        static let generated = Flags(rawValue: 1 << 0)
        static let imported = Flags(rawValue: 1 << 1)
    }
    
    enum CodingKeys : String, CodingKey {
        case identifier
        case firstName
        case lastName
        case phoneNumbers
        case emailAddresses
        case imageUrl
        case thumbnailUrl
        case flags
    }
}

extension Contact : Identifiable {
    var id: String { identifier }
}

extension Contact : Equatable {
}

extension Contact : Codable {
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        identifier = try values.decode(String.self, forKey: .identifier)
        firstName = try values.decode(String.self, forKey: .firstName)
        lastName = try values.decode(String.self, forKey: .lastName)
        phoneNumbers = try values.decode([LabeledValue<String, String>].self, forKey: .phoneNumbers)
        emailAddresses = try values.decode([LabeledValue<String, String>].self, forKey: .emailAddresses)
        
        let imageUrlString = try values.decode(String?.self, forKey: .imageUrl)
        imageUrl = imageUrlString.flatMap { URL(string: $0) }
        
        let thumbnailUrlString = try values.decode(String?.self, forKey: .thumbnailUrl)
        thumbnailUrl = thumbnailUrlString.flatMap { URL(string: $0) }
        
        flags = try values.decode(Flags.self, forKey: .flags)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(identifier, forKey: .identifier)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encode(phoneNumbers, forKey: .phoneNumbers)
        try container.encode(emailAddresses, forKey: .emailAddresses)
        try container.encode(imageUrl?.absoluteString, forKey: .imageUrl)
        try container.encode(thumbnailUrl?.absoluteString, forKey: .thumbnailUrl)
        try container.encode(flags, forKey: .flags)
    }
}
