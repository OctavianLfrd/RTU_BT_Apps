//
//  FileArchiver.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 30/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 92
 
 TOTAL DEPENDENCY DEGREE: 60
 
 */

import Foundation // [lines: 1]


protocol Archivable {
    func getArchivableUrl() async -> URL?
} // [lines: 4]

actor FileArchiver { // [lines: 5]
    
    static let shared = FileArchiver() // [lines: 6]
    
    private init() {
    } // [lines: 8]
    
    // [dd: 1]
    func archive(_ archivables: Archivable...) async -> URL? {
        return await archive(archivables) // [rd: { init archivables } (1)]
    } // [lines: 11]
    
    // [dd: 2]
    func archive(_ archivables: [Archivable]) async -> URL? {
        Logger.i("Archiving contents") // [rd: { init Logger } (1)]
        
        // closure: [dd: 11]
        return await withTaskGroup(of: URL?.self) { group in // [rd: { init archivables } (1)]
            for archivable in archivables {
                // closure: [dd: 1]
                group.addTask { // [rd: { init group, (for archivable) } (2)]
                    await archivable.getArchivableUrl() // [rd: { init archivable } (1)]
                }
            }
            
            var urls = [URL]()
            
            for await url in group where url != nil { // [rd: { (for await url) } (1)]
                urls.append(url!) // [rd: { var urls, urls.append(...), (for await url) } (3)]
            }
            
            guard let tempDirectory = storeContentsAtTempLocation(urls) else { // [rd: { var urls, urls.append(...) } (2)]
                return nil
            }
            
            guard let resultFile = archiveContent(tempDirectory) else { // [rd: { let tempDirectory } (1)]
                return nil
            }
            
            Logger.i("File archivation succeeded") // [rd: { init Logger } (1)]
            
            return resultFile // [rd: { let resultFile } (1)]
        }
    } // [lines: 33]
    
    // [dd: 18]
    private func archiveContent(_ url: URL) -> URL? {
        let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String]! // [rd: { init Bundle.main.infoDictionary, init kCFBundleNameKey } (2)]
        let uniqueString = ProcessInfo.processInfo.globallyUniqueString // [rd: { init ProcessInfo.processInfo } (1)]
        let fileName = "\(appName) files (\(uniqueString))" // [rd: { let appName, let uniqueString } (2)]
        
        var resultFile: URL? = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName) // [rd: { let fileName } (1)]
        var error: NSError?
        
        // closure: [dd: 6]
        NSFileCoordinator().coordinate(readingItemAt: url, options: .forUploading, error: &error) { archivableUrl in // [rd: { init url, var error, let fileName } (3)]
            do {
                resultFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName).appendingPathExtension(archivableUrl.pathExtension) // [rd: { let fileName, init archivableUrl } (2)]
                try FileManager.default.moveItem(at: archivableUrl, to: resultFile!) // [rd: { init archivableUrl, resultFile = URL(...), init FileManager.default } (3)]
            } catch {
                Logger.e("Failed to move archived content to result file") // [rd: { init Logger } (1)]
            }
        }
        
        if let error = error { // [rd: { var error } (1)]
            Logger.e("Failed to archive content [error=\(error)]") // [rd: { init Logger } (1)]
            return nil
        }
        
        guard let resultFile = resultFile else { // [rd: { var resultFile, resultFile = URL(...) } (2)]
            Logger.e("File with archived contents not found") // [rd: { init Logger } (1)]
            return nil
        }
        
        guard FileManager.default.fileExists(atPath: resultFile.path) else { // [rd: { init FileManager.default, let resultFile } (2)]
            Logger.e("File with archived contents does not exist") // [rd: { init Logger } (1)]
            return nil
        }
        
        return resultFile // [rd: { let resultFile } (1)]
    } // [lines: 61]
    
    // [dd: 21]
    private func storeContentsAtTempLocation(_ urls: [URL]) -> URL? {
        Logger.d("Storing contents at temporary directory") // [rd: { init Logger } (1)]
        
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true) // [rd: { init ProcessInfo.processInfo } (1)]
        
        do {
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: false, attributes: nil) // [rd: { init FileManager.default, let tempDirectory } (2)]
        } catch {
            Logger.e("Failed to create temporary directory to store app contents") // [rd: { init Logger } (1)]
            return nil
        }
        
        var contentStored = false
        
        for url in urls {
            var isDirectory: ObjCBool = false
            
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) { // [rd: { init FileManager.default, (for url).path, var isDirectory } (3)]
                do {
                    let destinationUrl = tempDirectory.appendingPathComponent(url.lastPathComponent, isDirectory: isDirectory.boolValue) // [rd: { let tempDirectory, (for url), isDirectory } (3)]
                    try FileManager.default.copyItem(at: url, to: destinationUrl) // [rd: { init FileManager.default, (for url), let destinationUrl } (3)]
                    
                    contentStored = true
                } catch {
                    Logger.e("Failed to copy file [url=\(url.absoluteString)]") // [rd: { init Logger, (for url) } (2)]
                }
            }
        }
        
        if contentStored { // [rd: { var contentStored, contentStored = true } (2)]
            Logger.d("Content stored at temporary directory") // [rd: { init Logger } (1)]
            return tempDirectory // [rd: { let tempDirectory } (1)]
        } else {
            Logger.d("No content stored at temporary directory") // [rd: { init Logger } (1)]
            return nil
        }
    } // [lines: 91]
} // [lines: 92]
