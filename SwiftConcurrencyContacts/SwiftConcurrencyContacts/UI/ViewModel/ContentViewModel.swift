//
//  ContentViewModel.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 30/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 99
 
 */

import Foundation
import MetricKit
import UIKit // [lines: 3]


@MainActor
class ContentViewModel : ObservableObject { // [lines: 5]
    
    @Published private(set) var contacts = [Contact]()
    @Published private(set) var isLoading = false
    @Published private(set) var sortType = SortType.auto // [lines: 8]
    
    private let contactSorter = ParallelMergeSorter<Contact>()
    private var sortTask: Task<[Contact]?, Never>? // [lines: 10]
    
    init() {
        Task(priority: .high) {
            await ContactStore.shared.addListener(self)
        }
    } // [lines: 15]
    
    func load() {
        isLoading = true
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreLoadingSignpostName)
        Task(priority: .high) {
            await ContactStore.shared.load()
            mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreLoadingSignpostName)
        }
    } // [lines: 21]
    
    func importContacts() {
        Task(priority: .high) {
            if let contacts = try? await ContactImporter.shared.importContacts() {
                mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
                await ContactStore.shared.storeContacts(contacts)
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
            }
        }
    } // [lines: 28]
    
    func generateContacts() {
        Task(priority: .high) {
            if let contacts = try? await ContactGenerator.shared.generateContacts(100) {
                mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
                await ContactStore.shared.storeContacts(contacts)
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
            }
        }
    } // [lines: 35]
    
    func exportAppContents() {
        mxSignpost(.begin, log: MetricObserver.fileExportLogHandle, name: MetricObserver.fileExportSignpostName)
        
        Task {
            defer {
                mxSignpost(.end, log: MetricObserver.fileExportLogHandle, name: MetricObserver.fileExportSignpostName)
            }
            
            guard
                let url = await FileArchiver.shared.archive(Logger(), ContactStore.shared, MetricObserver.shared),
                let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else {
                return
            }
            
            let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            
            windowScene.keyWindow?.rootViewController?.present(activityViewController, animated: true, completion: nil)
        }
    } // [lines: 47]
    
    func updateSortType(_ sortType: SortType) {
        guard self.sortType != sortType else {
            return
        }
        
        self.sortType = sortType
        
        Task {
            if let contacts = await sortContacts(contacts) {
                self.contacts = contacts
            }
        }
    } // [lines: 58]
    
    private func sortContacts(_ contacts: [Contact]) async -> [Contact]? {
        sortTask?.cancel()
        sortTask = nil
        
        if sortType == .random {
            return contacts.shuffled()
        } else {
            mxSignpost(.begin, log: MetricObserver.parallelSortingLogHandle, name: MetricObserver.contactSortingSignpostName)
            
            defer {
                mxSignpost(.end, log: MetricObserver.parallelSortingLogHandle, name: MetricObserver.contactSortingSignpostName)
            }
            
            sortTask = Task(priority: .high) {
                return try? await contactSorter.sort(contacts, comparator: getSortComparator())
            }
            
            return await sortTask?.value
        }
    } // [lines: 70]
    
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
    } // [lines: 82]
    
    enum SortType {
        case auto
        case firstName
        case lastName
        case random
    } // [lines: 88]
} // [lines: 89]

extension ContentViewModel : ContactStoreListener {
    
    func contactStore(_ contactStore: ContactStore, didUpdate contacts: [Contact]) {
        Task {
            if let contacts = await sortContacts(contacts) {
                self.isLoading = false
                self.contacts = contacts
            }
        }
    }
} // [lines: 99]
