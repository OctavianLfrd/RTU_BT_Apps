//
//  Logger.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

import Foundation


final class Logger {
    
    enum LogLevel {
        case debug
        case error
        case info
        case verbose
        case warning
        case other
    }
    
    private static let debugPrefix = "\u{1FAB2} [   DEBUG   ]"
    private static let errorPrefix = "\u{1F534} [   ERROR   ]"
    private static let infoPrefix = "\u{1F535} [   INFO    ]"
    private static let warningPrefix = "\u{1F7E1} [  WARNING  ]"
    private static let verbosePrefix = "\u{1F7E3} [  VERBOSE  ]"
    private static let otherPrefix = "\u{26AA}"
    
    private static let logDirectoryName = "Logs"
    
    private static let underlyingQueue = DispatchQueue(label: "Logger.Queue", qos: .background, target: .global(qos: .background))
    private static let operationQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = underlyingQueue
        operationQueue.maxConcurrentOperationCount = 1
        return operationQueue
    }()
    
    private static let dateFormatter = createDateFormatter()
    private static let fileHandle = createLogFile()
    
    static func d(_ message: String, file: String = #file, line: Int = #line) {
        print(.debug, message: message, file: file, line: line)
    }
    
    static func e(_ message: String, file: String = #file, line: Int = #line) {
        print(.error, message: message, file: file, line: line)
    }
    
    static func i(_ message: String, file: String = #file, line: Int = #line) {
        print(.info, message: message, file: file, line: line)
    }
    
    static func v(_ message: String, file: String = #file, line: Int = #line) {
        print(.verbose, message: message, file: file, line: line)
    }
    
    static func w(_ message: String, file: String = #file, line: Int = #line) {
        print(.warning, message: message, file: file, line: line)
    }
    
    static func o(_ message: String, file: String = #file, line: Int = #line) {
        print(.other, message: message, file: file, line: line)
    }
    
    static func print(_ level: LogLevel, message: String, file: String = #file, line: Int = #line) {
        operationQueue.addOperation {
            switch level {
            case .debug: writeLog(message, prefix: debugPrefix, timestamp: getCurrentTimeString(), file: file, line: line)
            case .error: writeLog(message, prefix: errorPrefix, timestamp: getCurrentTimeString(), file: file, line: line)
            case .info: writeLog(message, prefix: infoPrefix, timestamp: getCurrentTimeString(), file: file, line: line)
            case .verbose: writeLog(message, prefix: verbosePrefix, timestamp: getCurrentTimeString(), file: file, line: line)
            case .warning: writeLog(message, prefix: warningPrefix, timestamp: getCurrentTimeString(), file: file, line: line)
            case .other: writeLog(message, prefix: otherPrefix, timestamp: "", file: nil, line: nil)
            }
        }
    }
    
    private static func writeLog(_ message: String, prefix: String, timestamp: String, file: String?, line: Int?) {
        let timestampString = timestamp.isEmpty ? "" : "[\(timestamp)]"
        let fileString = file?.isEmpty != false ? "" : (file! as NSString).lastPathComponent
        let lineString = line == nil ? "" : "\(line!)"
        let fileLineDelimiter = !fileString.isEmpty && !lineString.isEmpty ? ":" : ""
        
        let log = "\(timestampString) \(prefix)\(fileString)\(fileLineDelimiter)\(lineString) - \(message)\n"
        
        let bytes = log.utf8.map { UInt8($0) }
        
        autoreleasepool {
            self.fileHandle?.seekToEndOfFile()
            self.fileHandle?.write(Data(bytes: bytes, count: bytes.count))
        }
        
#if DEBUG
        Swift.print(log)
#endif // DEBUG
    }
    
    private static func createDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm:ss.SSS"
        return formatter
    }
    
    private static func createLogFile() -> FileHandle? {
        let fileName = getCurrentTimeString()
        let logDirectory = getLogDirectoryUrl()
        
        if !FileManager.default.fileExists(atPath: logDirectory.path) {
            try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        let fileUrl = logDirectory.appendingPathComponent(fileName).appendingPathExtension("log")
        
        if !FileManager.default.fileExists(atPath: fileUrl.path) {
            FileManager.default.createFile(atPath: fileUrl.path, contents: nil, attributes: nil)
        }
        
        return try? FileHandle(forUpdating: fileUrl)
    }
    
    private static func getLogDirectoryUrl() -> URL {
        let libraryDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        
        return libraryDirectory.appendingPathComponent(Self.logDirectoryName, isDirectory: true)
    }
    
    private static func getCurrentTimeString() -> String {
        self.dateFormatter.string(from: Date())
    }
    
}

extension Logger : Archivable {
    
    func getArchivableUrl(_ completion: @escaping (URL?) -> Void) {
        Logger.operationQueue.addOperation {
            let logDirectoryUrl = Logger.getLogDirectoryUrl()
            
            guard FileManager.default.fileExists(atPath: logDirectoryUrl.path) else {
                completion(nil)
                return
            }
            
            completion(logDirectoryUrl)
        }
    }
}
