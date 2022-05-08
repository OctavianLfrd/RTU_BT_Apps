//
//  FileArchiver.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 19/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 108
 
 TOTAL DEPENDENCY DEGREE: 76
 
 */

import Foundation // [lines: 1]


protocol Archivable {
    func getArchivableUrl(_ completion: @escaping (URL?) -> Void)
} // [lines: 4]

class FileArchiver { // [lines: 5]
    
    static let shared = FileArchiver() // [lines: 6]
    
    private let queue = DispatchQueue(label: "FileArchiver.Queue", qos: .userInitiated, target: .global(qos: .userInitiated)) // [lines: 7]
    
    private init() {
    } // [lines: 9]
    
    // [dd: 2]
    func archive(_ archivables: Archivable..., completion: @escaping (URL?) -> Void) {
        archive(archivables, completion: completion) // [rd: { init archivables, init completion } (2)]
    } // [lines: 12]
    
    // [dd: 13]
    func archive(_ archivables: [Archivable], completion: @escaping (URL?) -> Void) {
        Logger.i("Archiving contents") // [rd: { init Logger } (1)]
        
        let group = DispatchGroup()
        var urls = Array<URL?>.init(repeating: nil, count: archivables.count) // [rd: { (init archivables).count) } (1)]
        
        for index in archivables.indices {
            group.enter() // [rd: { let group } (1)]
            
            // closure: [dd: 2]
            archivables[index].getArchivableUrl { url in // [rd: { init archivables, (for index), var urls, urls[index] = url, let group } (5)]
                urls[index] = url // [rd: { init url } (1)]
                group.leave() // [rd: { let group } (1)]
            }
        }
        
        // closure: [dd: 9]
        group.notify(queue: queue) { [self] in // [rd: { let group, init queue, var urls, urls[index] = url, init completion } (5)]
            guard let validUrls = filterContentUrls(urls) else { // [rd: { init urls } (1)]
                completion(nil) // [rd: { init completion } (1)]
                return
            }
            
            guard let tempDirectory = storeContentsAtTempLocation(validUrls) else { // [rd: { let validUrls } (1)]
                completion(nil) // [rd: { init completion } (1)]
                return
            }
            
            guard let resultFile = archiveContent(tempDirectory) else { // [rd: { let tempDirectory } (1)]
                completion(nil) // [rd: { init completion } (1)]
                return
            }
            
            Logger.i("File archivation succeeded") // [rd: { init Logger } (1)]
            
            completion(resultFile) // [rd: { init completion, let resultFile } (2)]
        }
    } // [lines: 40]
    
    // [dd: 4]
    private func filterContentUrls(_ urls: [URL?]) -> [URL]? {
        // closure: [dd: 1]
        let validUrls = urls.compactMap { $0 /* [rd: { init $0 } (1)] */ } // [rd: { init urls } (1)]
        
        if !validUrls.isEmpty { // [rd: { let validUrls } (1)]
            return validUrls // [rd: { let validUrls } (1)]
        } else {
            Logger.e("No content urls acquired") // [rd: { init Logger } (1)]
            return nil
        }
    } // [lines: 49]
    
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
    } // [lines: 77]
    
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
    } // [lines: 107]
} // [lines: 108]
