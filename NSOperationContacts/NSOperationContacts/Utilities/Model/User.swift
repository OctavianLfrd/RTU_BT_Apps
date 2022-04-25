//
//  User.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

import Foundation


struct User {
    let gender: String
    let name: Name
    let location: Location
    let email: String
    let login: Login
    let dateOfBirth: DateOfBirth
    let registrationData: RegistrationData
    let phone: String
    let cell: String
    let id: Id
    let picture: Picture
    let nat: String
    
    
    struct Name {
        let title: String
        let first: String
        let last: String
        
        
        enum CodingKeys : String, CodingKey {
            case title
            case first
            case last
        }
    }
    
    struct Location {
        let street: Street
        let city: String
        let state: String
        let country: String
        let postCode: String
        let coordinates: Coordinates
        let timeZone: TimeZone

        
        struct Street {
            let number: UInt
            let name: String
            
            
            enum CodingKeys : String, CodingKey {
                case number
                case name
            }
        }
        
        struct Coordinates {
            let latitude: String
            let longitude: String
            
            
            enum CodingKeys : String, CodingKey {
                case latitude
                case longitude
            }
        }
        
        struct TimeZone {
            let offset: String
            let description: String
            
            
            enum CodingKeys : String, CodingKey {
                case offset
                case description
            }
        }
        
        
        enum CodingKeys : String, CodingKey {
            case street
            case city
            case state
            case country
            case postCode = "postcode"
            case coordinates
            case timeZone = "timezone"
        }
    }
    
    struct Login {
        let uuid: String
        let userName: String
        let password: String
        let salt: String
        let md5: String
        let sha1: String
        let sha256: String
        
        
        enum CodingKeys : String, CodingKey {
            case uuid
            case userName = "username"
            case password
            case salt
            case md5
            case sha1
            case sha256
        }
    }
    
    struct DateOfBirth {
        let date: String
        let age: UInt
        
        
        enum CodingKeys : String, CodingKey {
            case date
            case age
        }
    }
    
    struct RegistrationData {
        let date: String
        let age: UInt
        
        
        enum CodingKeys : String, CodingKey {
            case date
            case age
        }
    }
    
    struct Id {
        let name: String
        let value: String?
        
        
        enum CodingKeys : String, CodingKey {
            case name
            case value
        }
    }
    
    struct Picture {
        let largeUrl: URL?
        let mediumUrl: URL?
        let thumbnailUrl: URL?
        
        
        enum CodingKeys : String, CodingKey {
            case largeUrl = "large"
            case mediumUrl = "medium"
            case thumbnailUrl = "thumbnail"
        }
    }
    
    
    enum CodingKeys : String, CodingKey {
        case gender
        case name
        case location
        case email
        case login
        case dataOfBirth = "dob"
        case registrationData = "registered"
        case phone
        case cell
        case id
        case picture
        case nat
    }
}

extension User : Decodable {
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        gender = try values.decode(String.self, forKey: .gender)
        name = try values.decode(Name.self, forKey: .name)
        location = try values.decode(Location.self, forKey: .location)
        email = try values.decode(String.self, forKey: .email)
        login = try values.decode(Login.self, forKey: .login)
        dateOfBirth = try values.decode(DateOfBirth.self, forKey: .dataOfBirth)
        registrationData = try values.decode(RegistrationData.self, forKey: .registrationData)
        phone = try values.decode(String.self, forKey: .phone)
        cell = try values.decode(String.self, forKey: .cell)
        id = try values.decode(Id.self, forKey: .id)
        picture = try values.decode(Picture.self, forKey: .picture)
        nat = try values.decode(String.self, forKey: .nat)
    }
}

extension User.Name : Decodable {
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try values.decode(String.self, forKey: .title)
        first = try values.decode(String.self, forKey: .first)
        last = try values.decode(String.self, forKey: .last)
    }
}

extension User.Location : Decodable {

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        street = try values.decode(Street.self, forKey: .street)
        city = try values.decode(String.self, forKey: .city)
        state = try values.decode(String.self, forKey: .state)
        country = try values.decode(String.self, forKey: .country)
        
        do {
            postCode = try values.decode(String.self, forKey: .postCode)
        }
        catch {
            postCode = String(try values.decode(Int.self, forKey: .postCode))
        }
        
        coordinates = try values.decode(Coordinates.self, forKey: .coordinates)
        timeZone = try values.decode(TimeZone.self, forKey: .timeZone)
    }
}

extension User.Location.Street : Decodable {
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        number = try values.decode(UInt.self, forKey: .number)
        name = try values.decode(String.self, forKey: .name)
    }
}

extension User.Location.Coordinates : Decodable {
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        latitude = try values.decode(String.self, forKey: .latitude)
        longitude = try values.decode(String.self, forKey: .longitude)
    }
}

extension User.Location.TimeZone : Decodable {
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        offset = try values.decode(String.self, forKey: .offset)
        description = try values.decode(String.self, forKey: .description)
    }
}

extension User.Login : Decodable {
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        uuid = try values.decode(String.self, forKey: .uuid)
        userName = try values.decode(String.self, forKey: .userName)
        password = try values.decode(String.self, forKey: .password)
        salt = try values.decode(String.self, forKey: .salt)
        md5 = try values.decode(String.self, forKey: .md5)
        sha1 = try values.decode(String.self, forKey: .sha1)
        sha256 = try values.decode(String.self, forKey: .sha256)
    }
}

extension User.DateOfBirth : Decodable {
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        date = try values.decode(String.self, forKey: .date)
        age = try values.decode(UInt.self, forKey: .age)
    }
}

extension User.RegistrationData : Decodable {
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        date = try values.decode(String.self, forKey: .date)
        age = try values.decode(UInt.self, forKey: .age)
    }
}

extension User.Id : Decodable {
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try values.decode(String.self, forKey: .name)
        value = try values.decode(String?.self, forKey: .value)
    }
}


extension User.Picture : Decodable {
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        let largeUrlString = try values.decode(String.self, forKey: .largeUrl)
        largeUrl = URL(string: largeUrlString)
        
        let mediumUrlString = try values.decode(String.self, forKey: .mediumUrl)
        mediumUrl = URL(string: mediumUrlString)
        
        let thumbnailUrlString = try values.decode(String.self, forKey: .thumbnailUrl)
        thumbnailUrl = URL(string: thumbnailUrlString)
    }
}
