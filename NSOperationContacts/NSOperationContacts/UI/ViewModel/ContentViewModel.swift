//
//  ContentViewModel.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 25/04/2022.
//

import Foundation
import UIKit
import MetricKit


class ContentViewModel : ObservableObject {
    
    @Published private(set) var contacts = [Contact]()
    @Published private(set) var isLoading = false
    @Published private(set) var sortType = SortType.auto
    
    private let sorterDispatchQueue: DispatchQueue
    
    private let contactSorter: ParallelMergeSorter<Contact>
    private var sortCancellationHandle: ParallelMergeSorter<Contact>.CancellationHandle?
    
    init() {
        sorterDispatchQueue = DispatchQueue(label: "ParallelMergeSorter.Queue", qos: .userInteractive, target: .global(qos: .userInteractive))
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = sorterDispatchQueue
        contactSorter = ParallelMergeSorter<Contact>(operationQueue)
        
        ContactStore.shared.addListener(self)
    }
    
    func load() {
        self.isLoading = true
        ContactStore.shared.load()
    }
    
    func importContacts() {
        ContactImporter.shared.importContacts { result in
            guard case let .success(contacts) = result else {
                return
            }
            
            ContactStore.shared.storeContacts(contacts)
        }
    }
    
    func generateContacts() {
        ContactGenerator.shared.generateContacts(100) { result in
            guard case let .success(contacts) = result else {
                return
            }
            
            ContactStore.shared.storeContacts(contacts)
        }
    }
    
    func exportAppContents() {
        mxSignpost(.begin, log: MetricObserver.fileExportLogHandle, name: MetricObserver.fileExportSignpostName)
        
        FileArchiver.shared.archive(Logger(), ContactStore.shared, MetricObserver.shared) { url in
            defer {
                mxSignpost(.end, log: MetricObserver.fileExportLogHandle, name: MetricObserver.fileExportSignpostName)
            }
            
            guard let url = url else {
                return
            }
            
            OperationQueue.main.addOperation { [weak self] in
                guard
                    let _ = self,
                    let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
                else {
                    return
                }
                
                let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                
                windowScene.keyWindow?.rootViewController?.present(activityViewController, animated: true, completion: nil)
            }
        }
    }
    
    func updateSortType(_ sortType: SortType) {
        guard self.sortType != sortType else {
            return
        }
        
        self.sortType = sortType
        sortContacts(contacts) { contacts in
            OperationQueue.main.addOperation { [weak self] in
                self?.contacts = contacts
            }
        }
    }
    
    private func sortContacts(_ contacts: [Contact], completion: @escaping ([Contact]) -> Void) {
        self.sortCancellationHandle?.cancel()
        self.sortCancellationHandle = nil
        
        if sortType == .random {
            completion(contacts.shuffled())
        } else {
            
            mxSignpost(.begin, log: MetricObserver.parallelSortingLogHandle, name: MetricObserver.contactSortingSignpostName)
            
            self.sortCancellationHandle = contactSorter.sort(contacts, comparator: getSortComparator()) { contacts in
                OperationQueue.main.addOperation { [weak self] in

                    mxSignpost(.end, log: MetricObserver.parallelSortingLogHandle, name: MetricObserver.contactSortingSignpostName)
                    
                    guard let self = self else {
                        return
                    }
                    
                    self.sortCancellationHandle = nil
                    completion(contacts)
                }
            }
        }
    }
    
    private func getSortComparator() -> ParallelMergeSorter<Contact>.Comparator {
        switch sortType {
        case .auto:
            return { c1, c2 in (c1.firstName + c1.lastName).lowercased() <= (c2.firstName + c2.lastName).lowercased() }
        case .firstName:
            return { c1, c2 in c1.firstName.lowercased() <= c2.firstName.lowercased() }
        case .lastName:
            return { c1, c2 in c1.lastName.lowercased() <= c2.lastName.lowercased() }
        case .random:
            fatalError("Unsupported sort type")
        }
    }
    
    deinit {
        self.sortCancellationHandle?.cancel()
        ContactStore.shared.removeListener(self)
    }
    
    enum SortType {
        case auto
        case firstName
        case lastName
        case random
    }
}

extension ContentViewModel : ContactStoreListener {
    
    func contactStore(_ contactStore: ContactStore, didUpdate contacts: [Contact]) {
        OperationQueue.main.addOperation { [weak self] in
            guard let self = self else {
                return
            }
            
            self.sortContacts(contacts) { contacts in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else {
                        return
                    }
                    
                    self.isLoading = false
                    self.contacts = contacts
                }
            }
        }
    }
}
