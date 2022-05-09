//
//  ContentViewModel.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 25/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 123
 
 TOTAL DEPENDENCY DEGREE: 64
 
 */

import Foundation
import UIKit
import MetricKit // [lines: 3]


class ContentViewModel : ObservableObject { // [lines: 4]
    
    @Published private(set) var contacts = [Contact]()
    @Published private(set) var isLoading = false
    @Published private(set) var sortType = SortType.auto // [lines: 7]
    
    private let sorterDispatchQueue: DispatchQueue // [lines: 8]
    
    private let contactSorter: ParallelMergeSorter<Contact>
    private var sortCancellationHandle: ParallelMergeSorter<Contact>.CancellationHandle? // [lines: 10]
    
    // [dd: 3]
    init() {
        sorterDispatchQueue = DispatchQueue(label: "ParallelMergeSorter.Queue", qos: .userInteractive, target: .global(qos: .userInteractive))
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = sorterDispatchQueue // [rd: { init sorterDispatchQueue } (1)]
        contactSorter = ParallelMergeSorter<Contact>(operationQueue) // [rd: { let operationQueue } (1)]
        
        ContactStore.shared.addListener(self) // [rd: { init ContactStore.shared } (1)]
    } // [lines: 17]
    
    // [dd: 1]
    func load() {
        self.isLoading = true
        ContactStore.shared.load() // [rd: { init ContactStore.shared } (1)]
    } // [lines: 21]
    
    // [dd: 1]
    func importContacts() {
        // closure: [dd: 3]
        ContactImporter.shared.importContacts { result in // [rd: { init ContactImporter.shared } (1)]
            guard case let .success(contacts) = result else { // [rd: { init result } (1)]
                return
            }
            
            ContactStore.shared.storeContacts(contacts) // [rd: { init ContactStore.shared, let .success(contacts) } (2)]
        }
    } // [lines: 29]
    
    // [dd: 1]
    func generateContacts() {
        // closure: [dd: 3]
        ContactGenerator.shared.generateContacts(200) { result in // [rd: { init ContactGenerator.shared } (1)]
            guard case let .success(contacts) = result else { // [rd: { init result } (1)]
                return
            }
            
            ContactStore.shared.storeContacts(contacts) // [rd: { init ContactStore.shared, let .success(contacts) } (2)]
        }
    } // [lines: 37]
    
    // [dd: 3]
    func exportAppContents() {
        mxSignpost(.begin, log: MetricObserver.fileExportLogHandle, name: MetricObserver.fileExportSignpostName)
        
        // closure: [dd: 3]
        FileArchiver.shared.archive(Logger(), ContactStore.shared, MetricObserver.shared) { url in // [rd: { init FileArchiver.shared, init ContactStore.shared, init MetricObserver.shared } (3)]
            defer {
                mxSignpost(.end, log: MetricObserver.fileExportLogHandle, name: MetricObserver.fileExportSignpostName)
            }
            
            guard let url = url else { // [rd: { init url } (1)]
                return
            }
            
            // closure: [dd: 5]
            OperationQueue.main.addOperation { [weak self] in // [rd: { let url, init OperationQueue.main } (2)]
                guard
                    let _ = self,
                    let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene // [rd: { weak self, UIApplication.shared } (2)]
                else {
                    return
                }
                
                let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil) // [rd: { init url } (1)]
                
                windowScene.keyWindow?.rootViewController?.present(activityViewController, animated: true, completion: nil) // [rd: { let windowScene, let activityViewController } (2)]
            }
        }
    } // [lines: 54]
    
    // [dd: 4]
    func updateSortType(_ sortType: SortType) {
        guard self.sortType != sortType else { // [rd: { init sortType, init self.sortType } (2)]
            return
        }
        
        self.sortType = sortType // [rd: { init sortType } (1)]
        // closure: [dd: 2]
        sortContacts(contacts) { contacts in // [rd: { init contacts } (1)]
            // closure: [dd: 1]
            OperationQueue.main.addOperation { [weak self] in // [rd: { init OperationQueue.main, init contacts } (2)]
                self?.contacts = contacts // [rd: { init contacts } (1)]
            }
        }
    } // [lines: 65]
    
    // [dd: 6]
    private func sortContacts(_ contacts: [Contact], completion: @escaping ([Contact]) -> Void) {
        self.sortCancellationHandle?.cancel() // [rd: { init sortCancellationhandle } (1)]
        self.sortCancellationHandle = nil
        
        if sortType == .random { // [rd: { init sortType } (1)]
            completion(contacts.shuffled())  // [rd: { init completion, init contacts } (2)]
        } else {
            
            mxSignpost(.begin, log: MetricObserver.parallelSortingLogHandle, name: MetricObserver.contactSortingSignpostName)
            
            // closure: [dd: 3]
            self.sortCancellationHandle = contactSorter.sort(contacts, comparator: getSortComparator()) { contacts in // [rd: { init contacts, init completion } (2)]
                // closure: [dd: 4]
                OperationQueue.main.addOperation { [weak self] in // [rd: { init OperationQueue.main, init contacts, init completion } (3)]

                    mxSignpost(.end, log: MetricObserver.parallelSortingLogHandle, name: MetricObserver.contactSortingSignpostName)
                    
                    guard let self = self else { // [rd: { weak self } (1)]
                        return
                    }
                    
                    self.sortCancellationHandle = nil // [rd: { let self } (1)]
                    completion(contacts) // [rd: { init completion, init contacts } (2)]
                }
            }
        }
    } // [lines: 82]
    
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
    } // [lines: 94]
    
    // [dd: 2]
    deinit {
        self.sortCancellationHandle?.cancel() // [rd: { init sortCancellationHandle } (1)]
        ContactStore.shared.removeListener(self) // [rd: { init ContactStore.shared } (1)]
    } // [lines: 98]
    
    enum SortType {
        case auto
        case firstName
        case lastName
        case random
    } // [lines: 104]
} // [lines: 105]

extension ContentViewModel : ContactStoreListener {
    
    // [dd: 2]
    func contactStore(_ contactStore: ContactStore, didUpdate contacts: [Contact]) {
        // closure:[dd: 3]
        OperationQueue.main.addOperation { [weak self] in // [rd: { init OperationQueue.main, init contacts } (2)]
            guard let self = self else { // [rd: { weak self } (1)]
                return
            }
            
            // closure: [dd: 2]
            self.sortContacts(contacts) { contacts in // [rd: { let self, init contacts } (2)]
                
                // closure: [dd: 3]
                DispatchQueue.main.async { [weak self] in // [rd: { init contacts, init OperationQueue.main } (2)]
                    guard let self = self else { // [rd: { weak self } (1)]
                        return
                    }
                    
                    self.isLoading = false // [rd: { let self } (1)]
                    self.contacts = contacts // [rd: { init contacts } (1)]
                }
            }
        }
    }
} // [lines: 123]
