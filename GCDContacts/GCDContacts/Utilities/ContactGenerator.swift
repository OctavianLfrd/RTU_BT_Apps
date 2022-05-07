//
//  ContactGenerator.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 13/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 110
 
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
    
    func generateContacts(_ count: Int, completion: @escaping GenerationCompletion) {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactGenerationSignpostName)
        
        workingQueue.async {
            self._generateContacts(count) { result in
                defer {
                    mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactGenerationSignpostName)
                }
                
                completion(result)
            }
        }
    } // [lines: 18]
    
    private func _generateContacts(_ count: Int, completion: @escaping GenerationCompletion) {
        guard activeRequestCount < Self.maxConcurrentRequests else {
            self.pendingRequests.append(PendingRequest(count: count, completion: completion))
            return
        }
        
        guard let request = createUserFetchRequest(count) else {
            completion(.requestFailed)
            return
        }
        
        activeRequestCount += 1
        
        Logger.i("Contact generation started [count=\(count)]")
        
        URLSession.shared.dataTask(with: request) { [self] data, response, error in
            
            func complete(_ result: Result) {
                completion(result)
                
                workingQueue.async { [self] in
                    activeRequestCount -= 1
                    if !pendingRequests.isEmpty {
                        let pendingRequest = pendingRequests.removeFirst()
                        _generateContacts(pendingRequest.count, completion: pendingRequest.completion)
                    }
                }
            }
            
            guard
                let data = data,
                let response = response as? HTTPURLResponse,
                response.statusCode == 200,
                error == nil
            else {
                Logger.e("Contact generation request failed [hasData=\(data != nil), isResponseValid=\((response as? HTTPURLResponse)?.statusCode == 200), error=\(String(describing: error))]")
                complete(.requestFailed)
                return
            }
            
            do {
                let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
                Logger.i("Contact generation succeeded")
                complete(.success(contacts: userResponse.users.map {
                    let contact = Contact($0)
                    Logger.v("Generated contact=\(contact)")
                    return contact
                }))
            } catch {
                Logger.i("Contact generation - contact parsing failed [error=\(error)]")
                complete(.parsingFailed)
            }
        }
        .resume()
    } // [lines: 65]
    
    private func createUserFetchRequest(_ count: Int) -> URLRequest? {
        guard count > 0, let url = composeUserFetchUrl(count) else {
            return nil
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        
        return request
    } // [lines: 73]
    
    private func composeUserFetchUrl(_ count: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "randomuser.me"
        components.path = "/api/"
        components.queryItems = [ URLQueryItem(name: "results", value: String(count)) ]
        return components.url
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
} // [lines: 110]
