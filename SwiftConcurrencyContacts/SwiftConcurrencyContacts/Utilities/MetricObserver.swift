//
//  MetricObserver.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 30/04/2022.
//

import Foundation
import MetricKit


class MetricObserver : NSObject {
    
    static let shared = MetricObserver()
    
    
    static let parallelSortingLogHandle = MXMetricManager.makeLogHandle(category: "ParallelSorting")
    static let contactOperationsLogHandle = MXMetricManager.makeLogHandle(category: "ContactOperations")
    static let loggerLogHandle = MXMetricManager.makeLogHandle(category: "Logger")
    static let fileExportLogHandle = MXMetricManager.makeLogHandle(category: "FileExport")
    
    
    static let contactSortingSignpostName: StaticString = "ContactSorting"
    static let contactImportSignpostName: StaticString = "ContactImport"
    static let contactGenerationSignpostName: StaticString = "ContactGeneration"
    static let contactStoreLoadingSignpostName: StaticString = "ContactStoreLoading"
    static let contactStoreStoring: StaticString = "ContactStoreStoring"
    static let contactStoreDeleting: StaticString = "ContactStoreDeleting"
    static let contactStoreTimerFrequency: StaticString = "ContactStoreTimerFrequency"
    static let loggerWriteSignpostName: StaticString = "LoggerWrite"
    static let fileExportSignpostName: StaticString = "FileExport"
    
    
    private static let mainDirectoryName = "MetricKit"
    private static let metricsDirectoryName = "Metrics"
    private static let diagnosticsDirectoryName = "Diagnostics"
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm:ss.SSS"
        return formatter
    } ()
    
    func start() {
        MXMetricManager.shared.add(self)
        
        Logger.i("Started observing metrics")
    }
    
}

extension MetricObserver : MXMetricManagerSubscriber {
    
    func didReceive(_ payloads: [MXMetricPayload]) {
        Logger.i("Received metrics payloads")
        
        guard let metricsDirectory = getOrCreateMetricsDirectory() else {
            Logger.e("Failed to get or create metrics directory")
            return
        }
        
        if payloads.count == 1 {
            if let fileName = createFile(metricsDirectory, data: payloads.first!.jsonRepresentation(), index: nil) {
                Logger.i("Stored payload in file '\(fileName)'")
            } else {
                Logger.e("Failed to store payload")
            }
        } else {
            for (index, payload) in payloads.enumerated() {
                if let fileName = createFile(metricsDirectory, data: payload.jsonRepresentation(), index: index) {
                    Logger.i("Stored metrics payload entry in file '\(fileName)'")
                } else {
                    Logger.e("Failed to store metrics payload entry")
                }
            }
        }
        
        Logger.i("Finished storing metrics payload")
    }
    
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        Logger.i("Received diagnostics payload")
        
        guard let diagnosticsDirectory = getOrCreateDiagnosticsDirectory() else {
            Logger.e("Failed to get or create diagnostics directory")
            return
        }
        
        if payloads.count == 1 {
            if let fileName = createFile(diagnosticsDirectory, data: payloads.first!.jsonRepresentation(), index: nil) {
                Logger.i("Stored diagnostics payload in file '\(fileName)'")
            } else {
                Logger.e("Failed to store diagnostics payload")
            }
        } else {
            for (index, payload) in payloads.enumerated() {
                if let fileName = createFile(diagnosticsDirectory, data: payload.jsonRepresentation(), index: index) {
                    Logger.i("Stored diagnostics payload entry in file '\(fileName)'")
                } else {
                    Logger.e("Failed to store diagnostics payload entry")
                }
            }
        }
        
        Logger.i("Finished storing diagnostics payload")
    }
    
    private func createFile(_ parentDirectory: URL, data: Data, index: Int?) -> String? {
        let fileName = dateFormatter.string(from: Date()) + (index.flatMap { " (\($0))" } ?? "")
        let fileUrl = parentDirectory.appendingPathComponent(fileName).appendingPathExtension("json")
        
        if !FileManager.default.fileExists(atPath: fileUrl.path) {
            let created = FileManager.default.createFile(atPath: fileUrl.path, contents: data)
            
            if created {
                return fileUrl.lastPathComponent
            }
        }
        
        return nil
    }
    
    private func getOrCreateMetricsDirectory() -> URL? {
        let metricsDirectory = getMetricKitDirectory().appendingPathComponent(Self.metricsDirectoryName, isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: metricsDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: metricsDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return nil
            }
        }
        
        return metricsDirectory
    }
    
    private func getOrCreateDiagnosticsDirectory() -> URL? {
        let diagnosticsDirectory = getMetricKitDirectory().appendingPathComponent(Self.diagnosticsDirectoryName, isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: diagnosticsDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: diagnosticsDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return nil
            }
        }
        
        return diagnosticsDirectory
    }
    
    private func getMetricKitDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(Self.mainDirectoryName, isDirectory: true)
    }
}

extension MetricObserver : Archivable {
    
    func getArchivableUrl() async -> URL? {
        getMetricKitDirectory()
    }
}
