//
//  FileArchiver.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 116
 
 */

import Foundation // [lines: 1]


protocol Archivable {
    func getArchivableUrl(_ completion: @escaping (URL?) -> Void)
} // [lines: 4]

class FileArchiver { // [lines: 5]
    
    static let shared = FileArchiver() // [lines: 6]
    
    private let operationQueue: OperationQueue
    private let underlyingQueue: DispatchQueue // [lines: 8]
    
    private init() {
        underlyingQueue = DispatchQueue(label: "FileArchiver.Queue", qos: .userInitiated, target: .global(qos: .userInitiated))
        operationQueue = OperationQueue()
        operationQueue.underlyingQueue = underlyingQueue
    } // [lines: 13]
    
    func archive(_ archivables: Archivable..., completion: @escaping (URL?) -> Void) {
        archive(archivables, completion: completion)
    } // [lines: 16]
    
    func archive(_ archivables: [Archivable], completion: @escaping (URL?) -> Void) {
        Logger.i("Archiving contents")
        
        var urls = Array<URL?>.init(repeating: nil, count: archivables.count)
        
        let archiveOperation = BlockOperation { [self] in
            guard let validUrls = filterContentUrls(urls) else {
                completion(nil)
                return
            }
            
            guard let tempDirectory = storeContentsAtTempLocation(validUrls) else {
                completion(nil)
                return
            }
            
            guard let resultFile = archiveContent(tempDirectory) else {
                completion(nil)
                return
            }
            
            Logger.i("File archivation succeeded")
            
            completion(resultFile)
        } // [lines: 35]
        
        var operations: [Operation] = [archiveOperation]
        
        for index in archivables.indices {
            let operation = AsyncBlockOperation { operationCompletion in
                archivables[index].getArchivableUrl { url in
                    urls[index] = url
                    operationCompletion()
                }
            }
            
            operations.append(operation)
            archiveOperation.addDependency(operation)
        }
        
        operationQueue.addOperations(operations, waitUntilFinished: false)
    } // [lines: 48]
    
    private func filterContentUrls(_ urls: [URL?]) -> [URL]? {
        let validUrls = urls.compactMap { $0 }
        
        if !validUrls.isEmpty {
            return validUrls
        } else {
            Logger.e("No content urls acquired")
            return nil
        }
    } // [lines: 57]
    
    private func archiveContent(_ url: URL) -> URL? {
        let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String]!
        let uniqueString = ProcessInfo.processInfo.globallyUniqueString
        let fileName = "\(appName) files (\(uniqueString))"
        
        var resultFile: URL? = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        var error: NSError?
        
        NSFileCoordinator().coordinate(readingItemAt: url, options: .forUploading, error: &error) { archivableUrl in
            do {
                resultFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName).appendingPathExtension(archivableUrl.pathExtension)
                try FileManager.default.moveItem(at: archivableUrl, to: resultFile!)
            } catch {
                Logger.e("Failed to move archived content to result file")
            }
        }
        
        if let error = error {
            Logger.e("Failed to archive content [error=\(error)]")
            return nil
        }
        
        guard let resultFile = resultFile else {
            Logger.e("File with archived contents not found")
            return nil
        }
        
        guard FileManager.default.fileExists(atPath: resultFile.path) else {
            Logger.e("File with archived contents does not exist")
            return nil
        }
        
        return resultFile
    } // [lines: 85]
    
    private func storeContentsAtTempLocation(_ urls: [URL]) -> URL? {
        Logger.d("Storing contents at temporary directory")
        
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: false, attributes: nil)
        } catch {
            Logger.e("Failed to create temporary directory to store app contents")
            return nil
        }
        
        var contentStored = false
        
        for url in urls {
            var isDirectory: ObjCBool = false
            
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                do {
                    let destinationUrl = tempDirectory.appendingPathComponent(url.lastPathComponent, isDirectory: isDirectory.boolValue)
                    try FileManager.default.copyItem(at: url, to: destinationUrl)
                    
                    contentStored = true
                } catch {
                    Logger.e("Failed to copy file [url=\(url.absoluteString)]")
                }
            }
        }
        
        if contentStored {
            Logger.d("Content stored at temporary directory")
            return tempDirectory
        } else {
            Logger.d("No content stored at temporary directory")
            return nil
        }
    } // [lines: 115]
} // [lines: 116]
