//
//  ContactGenerator.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 26/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 82
 
 TOTAL DEPENDENCY DEGREE: 44
 
 */

import Foundation
import MetricKit // [lines: 2]


class ContactGenerator { // [lines: 3]
    
    static let shared = ContactGenerator() // [lines: 4]
    
    private let semaphore = AsyncSemaphore(3) // [lines: 5]
    
    private init() {
    } // [lines: 7]
    
    // [dd: 3]
    func generateContacts(_ count: Int) async throws -> [Contact] {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactGenerationSignpostName)
        
        guard let request = createUserFetchRequest(count) else { // [rd: { init count } (1)]
            throw Error.requestFailed
        }
        
        // closure:[dd: 13]
        return try await semaphore.synchronize { // [rd: { init count, let request } (2)]
            defer {
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactGenerationSignpostName)
            }
            
            Logger.i("Contact generation started [count=\(count)]") // [rd: { init Logger } (1)]
            
            let data: Data
            let response: URLResponse
            
            do {
                (data, response) = try await URLSession.shared.data(for: request) // [rd: { init request, init URLSession.shared } (2)]
            } catch {
                Logger.e("Contact generation request failed [error=\(error)]") // [rd: { init Logger, init error } (2)]
                throw Error.requestFailed
            }
            
            guard // [rd: { (...,response) = URLSession..., (let response).statusCode } (2)]
                let response = response as? HTTPURLResponse,
                response.statusCode == 200
            else {
                Logger.e("Contact generation request failed - response invalid") // [rd: { init Logger } (1)]
                throw Error.requestFailed
            }
            
            do {
                let userResponse = try JSONDecoder().decode(UserResponse.self, from: data) // [rd: { (data,...) = URLSession... } (1)]
                Logger.i("Contact generation succeeded") // [rd: { init Logger } (1)]
                // closure: [dd: 4]
                return userResponse.users.map { // [rd: { (let userResponse).users } (1)]
                    let contact = Contact($0) // [rd: { init $0 } (1)]
                    Logger.v("Generated contact=\(contact)") // [rd: { init Logger, let contacts } (2)]
                    return contact // [rd: { let contact } (1)]
                }
            } catch {
                Logger.i("Contact generation - contact parsing failed [error=\(error)]") // [rd: { init Logger, init error } (2)]
                throw Error.parsingFailed
            }
        }
    } // [lines: 42]
    
    // [dd: 3]
    private func createUserFetchRequest(_ count: Int) -> URLRequest? {
        guard count > 0, let url = composeUserFetchUrl(count) else { // [rd: { init count } (1)]
            return nil
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30) // [rd: { let url = composeUserFetchUrl(count) } (1)]
        request.httpMethod = "GET"
        
        return request // [rd: { var request } (1)]
    } // [lines: 50]
    
    // [dd: 2]
    private func composeUserFetchUrl(_ count: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "randomuser.me"
        components.path = "/api/"
        components.queryItems = [ URLQueryItem(name: "results", value: String(count)) ] // [rd: { init count } (1)]
        return components.url // [rd: { var components } (1)]
    } // [lines: 58]
    
    enum Error : Swift.Error {
        case requestFailed
        case parsingFailed
    } // [lines: 62]
} // [lines: 63]

private extension Contact {
    
    // [dd: 7]
    init(_ user: User) {
        self.identifier = !user.login.uuid.isEmpty ? user.login.uuid : UUID().uuidString // [rd: { init user.logic.uuid } (1)]
        self.firstName = user.name.first // [rd: { user.name.first } (1)]
        self.lastName = user.name.last // [rd: { user.name.last } (1)]
        // closure: [dd: 12]
        self.phoneNumbers = { // [rd: { init user.cell, init user.phone } (2)]
            var phoneNumbers = [LabeledValue<String, String>]()
            
            if !user.cell.isEmpty { // [rd: { init user.cell } (1)]
                phoneNumbers.append(LabeledValue(label: Contact.phoneNumberLabelMobile, value: user.cell)) // [rd: { var phoneNumbers, Contact.phoneNumberLabelMobile, init user.cell } (3)]
            }
            if !user.phone.isEmpty { // [rd: { init user.phone } (1)]
                phoneNumbers.append(LabeledValue(label: Contact.phoneNumberLabelMain, value: user.phone)) // [rd: { var phoneNumbers, phoneNumbers.append(... user.cell)), user.phone, Contact.phoneNumberLabelMain } (4)]
            }
            
            return phoneNumbers // [rd: { var phoneNumbers, phoneNumbers.append(...), phoneNumbers.append(...) } (3)]
        } ()
        self.emailAddresses = !user.email.isEmpty ? [LabeledValue(label: Contact.emailLabelHome, value: user.email)] : [] // [rd: { init user.email, Contact.emailLabel } (2)]
        self.flags = .generated
    }
} // [lines: 82]
