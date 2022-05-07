//
//  ContactGenerator.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 26/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 82
 
 */

import Foundation
import MetricKit // [lines: 2]


class ContactGenerator { // [lines: 3]
    
    static let shared = ContactGenerator() // [lines: 4]
    
    private let semaphore = AsyncSemaphore(3) // [lines: 5]
    
    private init() {
    } // [lines: 7]
    
    func generateContacts(_ count: Int) async throws -> [Contact] {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactGenerationSignpostName)
        
        guard let request = createUserFetchRequest(count) else {
            throw Error.requestFailed
        }
        
        return try await semaphore.synchronize {
            defer {
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactGenerationSignpostName)
            }
            
            Logger.i("Contact generation started [count=\(count)]")
            
            let data: Data
            let response: URLResponse
            
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                Logger.e("Contact generation request failed [error=\(error)]")
                throw Error.requestFailed
            }
            
            guard
                let response = response as? HTTPURLResponse,
                response.statusCode == 200
            else {
                Logger.e("Contact generation request failed - response invalid")
                throw Error.requestFailed
            }
            
            do {
                let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
                Logger.i("Contact generation succeeded")
                return userResponse.users.map {
                    let contact = Contact($0)
                    Logger.v("Generated contact=\(contact)")
                    return contact
                }
            } catch {
                Logger.i("Contact generation - contact parsing failed [error=\(error)]")
                throw Error.parsingFailed
            }
        }
    } // [lines: 42]
    
    private func createUserFetchRequest(_ count: Int) -> URLRequest? {
        guard count > 0, let url = composeUserFetchUrl(count) else {
            return nil
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        
        return request
    } // [lines: 50]
    
    private func composeUserFetchUrl(_ count: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "randomuser.me"
        components.path = "/api/"
        components.queryItems = [ URLQueryItem(name: "results", value: String(count)) ]
        return components.url
    } // [lines: 58]
    
    enum Error : Swift.Error {
        case requestFailed
        case parsingFailed
    } // [lines: 62]
} // [lines: 63]

private extension Contact {
    
    init(_ user: User) {
        self.identifier = !user.login.uuid.isEmpty ? user.login.uuid : UUID().uuidString
        self.firstName = user.name.first
        self.lastName = user.name.last
        self.phoneNumbers = {
            var phoneNumbers = [LabeledValue<String, String>]()
            
            if !user.cell.isEmpty {
                phoneNumbers.append(LabeledValue(label: Contact.phoneNumberLabelMobile, value: user.cell))
            }
            if !user.phone.isEmpty {
                phoneNumbers.append(LabeledValue(label: Contact.phoneNumberLabelMain, value: user.phone))
            }
            
            return phoneNumbers
        } ()
        self.emailAddresses = !user.email.isEmpty ? [LabeledValue(label: Contact.emailLabelHome, value: user.email)] : []
        self.flags = .generated
    }
} // [lines: 82]
