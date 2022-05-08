//
//  ContentViewModel.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 30/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 99
 
 TOTAL DEPENDENCY DEGREE: 42
 
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
    
    // [dd: 0]
    init() {
        // closure: [dd: 1]
        Task(priority: .high) {
            await ContactStore.shared.addListener(self) // [rd: { init ContactStore.shared } (1)]
        }
    } // [lines: 15]
    
    // [dd: 0]
    func load() {
        isLoading = true
        mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreLoadingSignpostName)
        // closure: [dd: 1]
        Task(priority: .high) {
            await ContactStore.shared.load() // [rd: { init ContactStore.shared } (1)]
            mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreLoadingSignpostName)
        }
    } // [lines: 21]
    
    // [dd: 0]
    func importContacts() {
        // closure: [dd: 3]
        Task(priority: .high) {
            if let contacts = try? await ContactImporter.shared.importContacts() { // [rd: { init ContactImporter.shared } (1)]
                mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
                await ContactStore.shared.storeContacts(contacts) // [rd: { init ContactStore.shared, let contacts } (2)]
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
            }
        }
    } // [lines: 28]
    
    // [dd: 0]
    func generateContacts() {
        // closure: [dd: 3]
        Task(priority: .high) {
            if let contacts = try? await ContactGenerator.shared.generateContacts(100) { // [rd: { init ContactGenerator } (1)]
                mxSignpost(.begin, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
                await ContactStore.shared.storeContacts(contacts) // [rd: { init ContactStore.shared, let contacts } (2)]
                mxSignpost(.end, log: MetricObserver.contactOperationsLogHandle, name: MetricObserver.contactStoreStoring)
            }
        }
    } // [lines: 35]
    
    // [dd: 0]
    func exportAppContents() {
        mxSignpost(.begin, log: MetricObserver.fileExportLogHandle, name: MetricObserver.fileExportSignpostName)
        
        // closure: [dd: 7]
        Task {
            defer {
                mxSignpost(.end, log: MetricObserver.fileExportLogHandle, name: MetricObserver.fileExportSignpostName)
            }
            
            guard // [rd: { init FileArchiver.shared, init ContactStore.shared, init MetricObserver.shared, init UIApplication.shared } (4)]
                let url = await FileArchiver.shared.archive(Logger(), ContactStore.shared, MetricObserver.shared),
                let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else {
                return
            }
            
            let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil) // [rd: { let url } (1)]
            
            windowScene.keyWindow?.rootViewController?.present(activityViewController, animated: true, completion: nil) // [rd: { let windowScene, let activityViewController } (2)]
        }
    } // [lines: 47]
    
    // [dd: 3]
    func updateSortType(_ sortType: SortType) {
        guard self.sortType != sortType else { // [rd: { init self.sortType, init sortType } (2)]
            return
        }
        
        self.sortType = sortType // [rd: { init sortType } (1)]
        
        // closure: [dd: 2]
        Task {
            if let contacts = await sortContacts(contacts) { // [rd: { init self.contacts } (1)]
                self.contacts = contacts // [rd: { let contacts } (1)]
            }
        }
    } // [lines: 58]
    
    // [dd: 6]
    private func sortContacts(_ contacts: [Contact]) async -> [Contact]? {
        sortTask?.cancel() // [rd: { init sortTask } (1)]
        sortTask = nil
        
        if sortType == .random { // [rd: { init sortType } (1)]
            return contacts.shuffled() // [rd: { init contacts } (1)]
        } else {
            mxSignpost(.begin, log: MetricObserver.parallelSortingLogHandle, name: MetricObserver.contactSortingSignpostName)
            
            defer {
                mxSignpost(.end, log: MetricObserver.parallelSortingLogHandle, name: MetricObserver.contactSortingSignpostName)
            }
            
            // closure: [dd: 4]
            sortTask = Task.detached(priority: .high) { [weak self] in // [rd: { init Task, init contacts } (2)]
                guard let self = self else { // [rd: { weak self } (1)]
                    return nil
                }
                
                return try? await self.contactSorter.sort(contacts, comparator: self.getSortComparator()) // [rd: { let self, init contactSorter, init contacts } (3)]
            }
            
            return await sortTask?.value // [rd: { sortTask = Task.detached(...) } (1)]
        }
    } // [lines: 70]
    
    // [dd: 1]
    private func getSortComparator() -> ParallelMergeSorter<Contact>.Comparator {
        switch sortType { // [rd: { init sortType } (1)]
        case .auto:
            // closure: [dd: 4]
            return { c1, c2 in (c1.firstName + c1.lastName).lowercased() <= (c2.firstName + c2.lastName).lowercased() /* [rd: { init c1.firstName, init c2.firstName, init c1.lastName, init c2.lastName } (4)] */ }
        case .firstName:
            // closure: [dd: 2]
            return { c1, c2 in c1.firstName.lowercased() <= c2.firstName.lowercased() /* [rd: { init c1.firstName, init c2.firstName } (2)] */ }
        case .lastName:
            // closure: [dd: 2]
            return { c1, c2 in c1.lastName.lowercased() <= c2.lastName.lowercased() /* [rd: { init c1.lastName, init c2.lastName } (2)] */ }
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
    
    // [dd: 1]
    func contactStore(_ contactStore: ContactStore, didUpdate contacts: [Contact]) {
        // closure: [dd: 2]
        Task { // [rd: { init contacts } (1)]
            if let contacts = await sortContacts(contacts) { // [rd: { init contacts } (1)]
                self.isLoading = false
                self.contacts = contacts // [rd: { let contacts } (1)]
            }
        }
    }
} // [lines: 99]
