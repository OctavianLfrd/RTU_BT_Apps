//
//  FileArchiver.swift
//  SwiftConcurrencyContacts
//
//  Created by Alfred Lapkovsky on 30/04/2022.
//

import Foundation


protocol Archivable {
    func getArchivableUrl() async -> URL?
}

class FileArchiver {
    
    static let shared = FileArchiver()
    
    private init() {
    }
    
    func archive(_ archivables: Archivable...) async -> URL? {
        return await archive(archivables)
    }
    
    func archive(_ archivables: [Archivable]) async -> URL? {
        Logger.i("Archiving contents")
        
        return await withTaskGroup(of: URL?.self) { group in
            for archivable in archivables {
                group.addTask {
                    await archivable.getArchivableUrl()
                }
            }
            
            var urls = [URL]()
            
            for await url in group where url != nil {
                urls.append(url!)
            }
            
            guard let tempDirectory = storeContentsAtTempLocation(urls) else {
                return nil
            }
            
            guard let resultFile = archiveContent(tempDirectory) else {
                return nil
            }
            
            Logger.i("File archivation succeeded")
            
            return resultFile
        }
    }
    
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
    }
    
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
    }
}
