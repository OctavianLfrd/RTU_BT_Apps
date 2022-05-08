//
//  ContactGenerator.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 13/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 110
 
 TOTAL DEPENDENCY DEGREE: 71
 
 */

import Foundation
import MetricKit // [lines: 2]


class ContactGenerator { // [lines: 3]
    
    typealias GenerationCompletion = (Result) -> Void // [lines: 4]
    
    static let shared = ContactGenerator() // [lines: 5]
    
    private static let maxConcurrentRequests = 3 // [lines: 6]
    
    private var activeRequestCount = 0
    private var workingQueue = DispatchQueue(label: "ContactGenerator.Working", qos: .userInitiated, target: .global(qos: .userInitiated))
    private var pendingRequests: [PendingRequest] = [] // [lines: 9]
    
    private init() {
    } // [lines: 11]
    

    func generateContacts(_ count: Int, completion: @escaping GenerationCompletion) { // 1. rinda
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactGenerationSignpostName) // rinda netiek skaitīta

        workingQueue.async { // 2. rinda

            self._generateContacts(count) { result in // 3. rinda
                defer { // rinda netiek skaitīta
                    mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactGenerationSignpostName) // rinda netiek skaitīta
                } // rinda netiek skaitīta
                
                completion(result) // 4. rinda
            } // 5. rinda
        } // 6. rinda
    } // 7. rinda
    
    // [dd: 14]
    private func _generateContacts(_ count: Int, completion: @escaping GenerationCompletion) {
        guard activeRequestCount < Self.maxConcurrentRequests else { // [rd: { init activeRequestCount, init maxConcurrentRequests } (2)]
            self.pendingRequests.append(PendingRequest(count: count, completion: completion)) // [rd: { init count, init completion, init pendingRequests } (3)]
            return
        }
        
        guard let request = createUserFetchRequest(count) else { // [rd: { init count } (1)]
            completion(.requestFailed) // [rd: { init completion } (1)]
            return
        }
        
        activeRequestCount += 1 // [rd: { init activeRequestCount } (1)]
        
        Logger.i("Contact generation started [count=\(count)]") // [rd: { init count, init Logger } (2)]
        
        // closure: [dd: 14]
        URLSession.shared.dataTask(with: request) { [self] data, response, error in // [rd: { request = createUserFetchRequest(count), init completion, init URLSession.shared } (3)]
            
            // [dd: 3]
            func complete(_ result: Result) {
                completion(result) // [rd: { init completion, init result } (2)]
                
                // closure: [dd: 5]
                workingQueue.async { [self] in // [rd: { init workingQueue } (1)]
                    activeRequestCount -= 1 // [rd: { init activeRequestCount } (1)]
                    if !pendingRequests.isEmpty { // [rd: { init pendingRequests } (1)]
                        let pendingRequest = pendingRequests.removeFirst() // [rd: { init pendingRequets } (1)]
                        _generateContacts(pendingRequest.count, completion: pendingRequest.completion) // [rd: { init pendingRequest.count, init pendingRequest.completion } (2)]
                    }
                }
            }
            
            guard // [rd: { init data, init response, (let response).statusCode, init error } (4)]
                let data = data,
                let response = response as? HTTPURLResponse,
                response.statusCode == 200,
                error == nil
            else {
                // [rd: { init data, init response, init response.statusCode, init error, init Logger } (5)
                Logger.e("Contact generation request failed [hasData=\(data != nil), isResponseValid=\((response as? HTTPURLResponse)?.statusCode == 200), error=\(String(describing: error))]")
                complete(.requestFailed)
                return
            }
            
            do {
                let userResponse = try JSONDecoder().decode(UserResponse.self, from: data) // [rd: { let data = data } (1)]
                Logger.i("Contact generation succeeded") // [rd: { init Logger } (1)]
                
                // closure: [dd: 4]
                complete(.success(contacts: userResponse.users.map { // [rd: { (let userResponse).users } (1)]
                    let contact = Contact($0) // [rd: { init $0 } (1)]
                    Logger.v("Generated contact=\(contact)") // [rd: { init Logger, let contact } (2)]
                    return contact // [rd: { let contact } (1)]
                }))
            } catch {
                Logger.i("Contact generation - contact parsing failed [error=\(error)]") // [rd: { init Logger, init error } (2)]
                complete(.parsingFailed)
            }
        }
        .resume() // [rd: { URLSession.shared.dataTask(...) } (1)]
    } // [lines: 65]
    
    // [dd: 3]
    private func createUserFetchRequest(_ count: Int) -> URLRequest? {
        guard count > 0, let url = composeUserFetchUrl(count) else { // [rd: { init count } (1)]
            return nil
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30) // [rd: { let url = composeUserFetchUrl(count) } (1)]
        request.httpMethod = "GET"
        
        return request // [rd: { var request } (1)]
    } // [lines: 73]
    
    // [dd: 2]
    private func composeUserFetchUrl(_ count: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "randomuser.me"
        components.path = "/api/"
        components.queryItems = [ URLQueryItem(name: "results", value: String(count)) ] // [rd: { init count } (1)]
        return components.url // [rd: { var components } (1)]
    } // [lines: 81]
    
    struct PendingRequest {
        let count: Int
        let completion: GenerationCompletion
    } // [lines: 85]
    
    enum Result {
        case success(contacts: [Contact])
        case requestFailed
        case parsingFailed
    } // [lines: 90]
} // [lines: 91]


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
} // [lines: 110]
