//
//  ContentViewModel.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 14/04/2022.
//

import Foundation


class ContentViewModel : ObservableObject {
    
    @Published private(set) var contacts = [Contact]()
    @Published private(set) var isLoading = false
    @Published private(set) var sortType = SortType.auto
    
    private let contactSorter = ParallelMergeSorter<Contact>(DispatchQueue(label: "ParallelMergeSorter.Queue", qos: .userInteractive, target: .global(qos: .userInteractive)))
    private var sortCancellationHandle: ParallelMergeSorter<Contact>.CancellationHandle?
    
    init() {
        ContactStore.shared.addListener(self)
    }
    
    deinit {
        self.sortCancellationHandle?.cancel()
        ContactStore.shared.removeListener(self)
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
    
    func updateSortType(_ sortType: SortType) {
        guard self.sortType != sortType else {
            return
        }
        
        self.sortType = sortType
        self.sortContacts(contacts) { contacts in
            DispatchQueue.main.async { [weak self] in
                self?.contacts = contacts
            }
        }
    }
    
    private func sortContacts(_ contacts: [Contact], completion: @escaping ([Contact]) -> Void) {
        self.sortCancellationHandle?.cancel()
        self.sortCancellationHandle = contactSorter.sort(contacts, comparator: self.getSortComparator()) { contacts in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                self.sortCancellationHandle = nil
                completion(contacts)
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
        }
    }
    
    enum SortType {
        case auto
        case firstName
        case lastName
    }
}

extension ContentViewModel : ContactStoreListener {
    func contactStore(_ contactStore: ContactStore, didUpdate contacts: [Contact]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            
            self.sortContacts(contacts) { contacts in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else {
                        return
                    }
                    
                    if self.contacts.isEmpty {
                        self.isLoading = false
                    }
                    
                    self.contacts = contacts
                }
            }
        }
    }
}
