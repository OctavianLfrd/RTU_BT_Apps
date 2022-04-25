//
//  ContactGenerator.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

import Foundation
import MetricKit


class ContactGenerator {
    
    typealias GenerationCompletion = (Result) -> Void
    
    static let shared = ContactGenerator()
        
    private let operationQueue: OperationQueue
    private let underlyingQueue: DispatchQueue
    
    private init() {
        underlyingQueue = DispatchQueue(label: "ContactGenerator.Working", qos: .userInitiated, attributes: .concurrent, target: .global(qos: .userInitiated))
        operationQueue = OperationQueue()
        operationQueue.underlyingQueue = underlyingQueue
        operationQueue.maxConcurrentOperationCount = 3
    }
    
    func generateContacts(_ count: Int, completion: @escaping GenerationCompletion) {
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactGenerationSignpostName)
        
        operationQueue.addOperation(AsyncBlockOperation { [self] operationCompletion in
            
            func complete(_ result: Result) {
                defer {
                    mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactGenerationSignpostName)
                }
                
                completion(result)
                operationCompletion()
            }
            
            guard let request = composeUserFetchUrl(count) else {
                complete(.requestFailed)
                return
            }
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                guard
                    let data = data,
                    let response = response as? HTTPURLResponse,
                    response.statusCode == 200,
                    error == nil
                else {
                    complete(.requestFailed)
                    return
                }
                
                do {
                    let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
                    complete(.success(contacts: userResponse.users.map { Contact($0) }))
                } catch {
                    complete(.parsingFailed)
                }
            }
            .resume()
        })
    }
    
    private func createUserFetchRequest(_ count: Int) -> URLRequest? {
        guard count > 0, let url = composeUserFetchUrl(count) else {
            return nil
        }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        
        return nil
    }
    
    private func composeUserFetchUrl(_ count: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "randomuser.me"
        components.path = "/api/"
        components.queryItems = [ URLQueryItem(name: "results", value: String(count)) ]
        return components.url
    }
    
    enum Result {
        case success(contacts: [Contact])
        case requestFailed
        case parsingFailed
    }
}

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
        self.imageUrl = user.picture.largeUrl
        self.thumbnailUrl = user.picture.thumbnailUrl
        self.flags = .generated
    }
}
