//
//  ContactGenerator.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 13/04/2022.
//

import Foundation


class ContactGenerator {
    
    typealias GenerationCompletion = (Result) -> Void
    
    static let shared = ContactGenerator()
    
    private static let maxConcurrentRequests = 3
    
    private var activeRequestCount = 0
    private var totalRequestCount = 0
    private var workingQueue = DispatchQueue(label: "ContactGenerator.Working", qos: .userInitiated, target: .global(qos: .userInitiated))
    private var pendingRequests: [PendingRequest] = []
    
    private init() {
    }
    
    func generateContacts(_ count: Int, completion: @escaping GenerationCompletion) {
        workingQueue.async {
            self._generateContacts(count, completion: completion)
        }
    }
    
    private func _generateContacts(_ count: Int, completion: @escaping GenerationCompletion) {
        guard let request = composeUserFetchUrl(count) else {
            completion(.requestFailed)
            return
        }
        
        guard activeRequestCount < Self.maxConcurrentRequests else {
            self.pendingRequests.append(PendingRequest(count: count, completion: completion))
            return
        }
        
        activeRequestCount += 1
        totalRequestCount += 1
        
        let currentRequest = totalRequestCount
        
        Logger.i("Contact generation[\(currentRequest)] started [count=\(count)]")
        
        URLSession.shared.dataTask(with: request) { [self] data, response, error in
            
            func complete(_ result: Result) {
                workingQueue.async { [self] in
                    completion(result)
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
                Logger.e("Contact generation[\(currentRequest)] request failed [hasData=\(data != nil), isResponseValid=\((response as? HTTPURLResponse)?.statusCode == 200), error=\(String(describing: error))]")
                complete(.requestFailed)
                return
            }
            
            do {
                let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
                Logger.i("Contact generation[\(currentRequest)] succeeded")
                complete(.success(contacts: userResponse.users.map { Contact($0) }))
            } catch {
                Logger.i("Contact generation[\(currentRequest)] contact parsing failed \(error)")
                complete(.parsingFailed)
            }
        }
        .resume()
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
    
    
    struct PendingRequest {
        let count: Int
        let completion: GenerationCompletion
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
