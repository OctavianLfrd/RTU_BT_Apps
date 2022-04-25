//
//  ContentViewModel.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 14/04/2022.
//

import Foundation
import MetricKit
import UIKit


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
    
    func exportAppContents() {
        mxSignpost(.begin, log: MetricObserver.fileExportLogHandle, name: MetricObserver.fileExportSignpostName)
        
        FileArchiver.shared.archive(Logger(), ContactStore.shared, MetricObserver.shared) { url in
            defer {
                mxSignpost(.end, log: MetricObserver.fileExportLogHandle, name: MetricObserver.fileExportSignpostName)
            }
            
            guard let url = url else {
                return
            }
            
            DispatchQueue.main.async { [weak self] in
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
            DispatchQueue.main.async { [weak self] in
                self?.contacts = contacts
            }
        }
    }
    
    private func sortContacts(_ contacts: [Contact], completion: @escaping ([Contact]) -> Void) {
        sortCancellationHandle?.cancel()
        sortCancellationHandle = nil
        
        if sortType == .random {
            completion(contacts.shuffled())
        } else {
            
            mxSignpost(.begin, log: MetricObserver.parallelSortingLogHandle, name: MetricObserver.contactSortingSignpostName)
            
            sortCancellationHandle = contactSorter.sort(contacts, comparator: getSortComparator()) { contacts in
                DispatchQueue.main.async { [weak self] in
                    
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
    
    enum SortType {
        case auto
        case firstName
        case lastName
        case random
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
                    
                    self.isLoading = false
                    self.contacts = contacts
                }
            }
        }
    }
}
