//
//  FileArchiver.swift
//  GCDContacts
//
//  Created by Alfred Lapkovsky on 19/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 108
 
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
    
    func archive(_ archivables: Archivable..., completion: @escaping (URL?) -> Void) {
        archive(archivables, completion: completion)
    } // [lines: 12]
    
    func archive(_ archivables: [Archivable], completion: @escaping (URL?) -> Void) {
        Logger.i("Archiving contents")
        
        let group = DispatchGroup()
        var urls = Array<URL?>.init(repeating: nil, count: archivables.count)
        
        for index in archivables.indices {
            group.enter()
                
            archivables[index].getArchivableUrl { url in
                urls[index] = url
                group.leave()
            }
        }
        
        group.notify(queue: queue) { [self] in
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
        }
    } // [lines: 40]
    
    private func filterContentUrls(_ urls: [URL?]) -> [URL]? {
        let validUrls = urls.compactMap { $0 }
        
        if !validUrls.isEmpty {
            return validUrls
        } else {
            Logger.e("No content urls acquired")
            return nil
        }
    } // [lines: 49]
    
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
    } // [lines: 77]
    
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
    } // [lines: 107]
} // [lines: 108]
