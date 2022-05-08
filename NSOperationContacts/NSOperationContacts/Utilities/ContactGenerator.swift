//
//  ContactGenerator.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 92
 
 TOTAL DEPENDENCY DEGREE: 55
 
 */

import Foundation
import MetricKit // [lines: 2]


class ContactGenerator { // [lines: 3]
    
    typealias GenerationCompletion = (Result) -> Void // [lines: 4]
    
    static let shared = ContactGenerator() // [lines: 5]
        
    private let operationQueue: OperationQueue
    private let underlyingQueue: DispatchQueue // [lines: 7]
    
    // [dd: 1]
    private init() {
        underlyingQueue = DispatchQueue(label: "ContactGenerator.Working", qos: .userInitiated, attributes: .concurrent, target: .global(qos: .userInitiated))
        operationQueue = OperationQueue()
        operationQueue.underlyingQueue = underlyingQueue // [rd: { init underlyingQueue } (1)]
        operationQueue.maxConcurrentOperationCount = 3
    } // [lines: 13]
    
    // [dd: 3]
    func generateContacts(_ count: Int, completion: @escaping GenerationCompletion) {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactGenerationSignpostName)
        
        // closure: [dd: 6]
        operationQueue.addOperation(AsyncBlockOperation { [self] operationCompletion in // [rd: { init operationQueue, init count, init completion } (3)]
            
            // [dd: 3]
            func complete(_ result: Result) {
                defer {
                    mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactGenerationSignpostName)
                }
                
                completion(result) // [rd: { init completion, init result } (2)]
                operationCompletion() // [rd: { init operationCompletion } (1)]
            }
            
            guard let request = createUserFetchRequest(count) else { // [rd: { init count } (1)]
                complete(.requestFailed)
                return
            }
            
            Logger.i("Contact generation started [count=\(count)]") // [rd: { init Logger, init count } (2)]
            
            // closure: [dd: 14]
            URLSession.shared.dataTask(with: request) { data, response, error in // [rd: { let request, init URLSession.shared } (2)]
                guard // [rd: { init data, init response, (let response).statusCode, init error } (4)]
                    let data = data,
                    let response = response as? HTTPURLResponse,
                    response.statusCode == 200,
                    error == nil
                else {
                    // [rd: { init data, init response, init response.statusCode, init error, init Logger } (5)]
                    Logger.e("Contact generation request failed [hasData=\(data != nil), isResponseValid=\((response as? HTTPURLResponse)?.statusCode == 200), error=\(String(describing: error))]")
                    complete(.requestFailed)
                    return
                }
                
                do {
                    let userResponse = try JSONDecoder().decode(UserResponse.self, from: data) // [rd: { init data } (1)]
                    Logger.i("Contact generation succeeded") // [rd: { init Logger } (1)]
                    
                    // closure: [dd: 4]
                    complete(.success(contacts: userResponse.users.map { // [rd: { (let userResponse).users) } (1)]
                        let contact = Contact($0) // [rd: { init $0 } (1)]
                        Logger.v("Generated contact=\(contact)") // [rd: { init Logger, let contacts } (2)]
                        return contact // [rd: { let contact } (1)]
                    }))
                } catch {
                    Logger.e("Contact generation - contact parsing failed [error=\(error)]") // [rd: { init Logger, init error } (2)]
                    complete(.parsingFailed)
                }
            }
            .resume() // [rd: { URLSession.shared.dataTask(...) } (1)]
        })
    } // [lines: 51]
    
    // [dd: 3]
    private func createUserFetchRequest(_ count: Int) -> URLRequest? {
        guard count > 0, let url = composeUserFetchUrl(count) else { // [rd: { init count } (1)]
            return nil
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30) // [rd: { let url = composeUserFetchUrl(count) } (1)]
        request.httpMethod = "GET"
        
        return request // [rd: { var request } (1)]
    } // [lines: 59]
    
    // [dd: 2]
    private func composeUserFetchUrl(_ count: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "randomuser.me"
        components.path = "/api/"
        components.queryItems = [ URLQueryItem(name: "results", value: String(count)) ] // [rd: { init count } (1)]
        return components.url // [rd: { var components } (1)]
    } // [lines: 67]
    
    enum Result {
        case success(contacts: [Contact])
        case requestFailed
        case parsingFailed
    } // [lines: 72]
} // [lines: 73]

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
} // [lines: 92]
