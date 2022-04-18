//
//  UserResponse.swift
//  GCDTestApp
//
//  Created by Alfred Lapkovsky on 12/04/2022.
//

import Foundation


struct UserResponse {
    let users: [User]
    let info: Info
    
    
    struct Info {
        let seed: String
        let count: UInt
        let page: UInt
        let version: String
    
        
        enum CodingKeys : String, CodingKey {
            case seed
            case count = "results"
            case page
            case version
        }
    }
    
    
    enum CodingKeys : String, CodingKey {
        case users = "results"
        case info
    }
}

extension UserResponse : Decodable {
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        users = try values.decode([User].self, forKey: .users)
        info = try values.decode(Info.self, forKey: .info)
    }
}

extension UserResponse.Info : Decodable {
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        seed = try values.decode(String.self, forKey: .seed)
        count = try values.decode(UInt.self, forKey: .count)
        page = try values.decode(UInt.self, forKey: .page)
        version = try values.decode(String.self, forKey: .version)
    }
}
