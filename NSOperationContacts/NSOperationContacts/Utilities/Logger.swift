//
//  Logger.swift
//  NSOperationContacts
//
//  Created by Alfred Lapkovsky on 20/04/2022.
//

/**
 
 MEANINGFUL LINES OF CODE: 109
 
 TOTAL DEPENDENCY DEGREE: 91
 
 */

import Foundation
import MetricKit // [lines: 2]


final class Logger { // [lines: 3]
    
    enum LogLevel {
        case debug
        case error
        case info
        case verbose
        case warning
        case other
    } // [lines: 11]
    
    private static let debugPrefix = "\u{1FAB2} [   DEBUG   ]"
    private static let errorPrefix = "\u{1F534} [   ERROR   ]"
    private static let infoPrefix = "\u{1F535} [   INFO    ]"
    private static let warningPrefix = "\u{1F7E1} [  WARNING  ]"
    private static let verbosePrefix = "\u{1F7E3} [  VERBOSE  ]"
    private static let otherPrefix = "\u{26AA}" // [lines: 17]
    
    private static let logDirectoryName = "Logs" // [lines: 18]
    
    private static let underlyingQueue = DispatchQueue(label: "Logger.Queue", qos: .background, target: .global(qos: .background))
    
    // [dd: 2]
    private static let operationQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = underlyingQueue // [rd: { init underlyingQueue } (1)]
        operationQueue.maxConcurrentOperationCount = 1
        return operationQueue // [rd: { let operationQueue } (1)]
    }() // [lines: 25]
    
    private static let dateFormatter = createDateFormatter()
    private static let fileHandle = createLogFile() // [lines: 27]
    
    // [dd: 3]
    static func d(_ message: String, file: String = #file, line: Int = #line) {
        print(.debug, message: message, file: file, line: line) // [rd: { init message, init file, init line } (3)]
    } // [lines: 30]
    
    // [dd: 3]
    static func e(_ message: String, file: String = #file, line: Int = #line) {
        print(.error, message: message, file: file, line: line) // [rd: { init message, init file, init line } (3)]
    } // [lines: 33]
    
    // [dd: 3]
    static func i(_ message: String, file: String = #file, line: Int = #line) {
        print(.info, message: message, file: file, line: line) // [rd: { init message, init file, init line } (3)]
    } // [lines: 36]
    
    // [dd: 3]
    static func v(_ message: String, file: String = #file, line: Int = #line) {
        print(.verbose, message: message, file: file, line: line) // [rd: { init message, init file, init line } (3)]
    } // [lines: 39]
    
    // [dd: 3]
    static func w(_ message: String, file: String = #file, line: Int = #line) {
        print(.warning, message: message, file: file, line: line) // [rd: { init message, init file, init line } (3)]
    } // [lines: 42]
    
    // [dd: 3]
    static func o(_ message: String, file: String = #file, line: Int = #line) {
        print(.other, message: message, file: file, line: line) // [rd: { init message, init file, init line } (3)]
    } // [lines: 45]
    
    // [dd: 5]
    static func print(_ level: LogLevel, message: String, file: String = #file, line: Int = #line) {
        mxSignpost(.begin, log: MetricObserver.loggerLogHandle, name: MetricObserver.loggerWriteSignpostName)
        
        // closure: [dd: 23]
        operationQueue.addOperation {  // [rd: { init operationQueue, init level, init message, init file, init line } (5)]
            defer {
                mxSignpost(.end, log: MetricObserver.loggerLogHandle, name: MetricObserver.loggerWriteSignpostName)
            }
            
            switch level { // [rd: { init level } (1)]
            case .debug: writeLog(message, prefix: debugPrefix, timestamp: getCurrentTimeString(), file: file, line: line) // [rd: { init mesasge, init file, init line, init debugPrefix } (4)]
            case .error: writeLog(message, prefix: errorPrefix, timestamp: getCurrentTimeString(), file: file, line: line) // [rd: { init message, init file, init line, init errorPrefix } (4)]
            case .info: writeLog(message, prefix: infoPrefix, timestamp: getCurrentTimeString(), file: file, line: line) // [rd: { init message, init file, init line, init infoPrefix } (4)]
            case .verbose: writeLog(message, prefix: verbosePrefix, timestamp: getCurrentTimeString(), file: file, line: line) // [rd: { init message, init file, init line, init verbosePrefix } (4)]
            case .warning: writeLog(message, prefix: warningPrefix, timestamp: getCurrentTimeString(), file: file, line: line) // [rd: { init message, init file, init line, init warningPrefix } (4)]
            case .other: writeLog(message, prefix: otherPrefix, timestamp: "", file: nil, line: nil) // [rd: { init message, init otherPrefix } (2)]
            }
        }
    } // [lines: 57]
    
    // [dd: 14]
    private static func writeLog(_ message: String, prefix: String, timestamp: String, file: String?, line: Int?) {
        let timestampString = timestamp.isEmpty ? "" : "[\(timestamp)]" // [rd: { init timestamp } (1)]
        let fileString = file?.isEmpty != false ? "" : (file! as NSString).lastPathComponent // [rd: { init file } (1)]
        let lineString = line == nil ? "" : "\(line!)" // [rd: { init line } (1)]
        let fileLineDelimiter = !fileString.isEmpty && !lineString.isEmpty ? ":" : "" // [rd: { let fileString, let lineString } (2)]
        
        let log = "\(timestampString) \(prefix)\(fileString)\(fileLineDelimiter)\(lineString) - \(message)\n" // [rd: { let timestampString, init prefix, let fileString, let fileLineDelimiter, let lineString, init message } (6)]
        
        // closure: [dd: 1]
        let bytes = log.utf8.map { UInt8($0) /* [rd: { init $0 } (1)] */ } // [rd: { let log } (1)]
        
        // closure: [dd: 4]
        autoreleasepool { // [rd: { let bytes } (1)]
            self.fileHandle?.seekToEndOfFile() // [rd: { init fileHandle } (1)]
            self.fileHandle?.write(Data(bytes: bytes, count: bytes.count)) // [rd: { init fileHandle, init bytes, (init bytes).count } (3)]
        }
        
#if DEBUG
        Swift.print(log) // [rd: { let log } (1)]
#endif // DEBUG
    } // [lines: 72]
    
    // [dd: 1]
    private static func createDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm:ss.SSS"
        return formatter // [rd: { let formatter } (1)]
    } // [lines: 77]
    
    // [dd: 11]
    private static func createLogFile() -> FileHandle? {
        let fileName = getCurrentTimeString()
        let logDirectory = getLogDirectoryUrl()
        
        if !FileManager.default.fileExists(atPath: logDirectory.path) { // [rd: { (let logDirectory).path, init FileManager.default } (2)]
            try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true, attributes: nil) // [rd: { init FileManager.default, let logDirectory } (2)]
        }
        
        let fileUrl = logDirectory.appendingPathComponent(fileName).appendingPathExtension("log") // [rd: { let lodDirectory, let fileName } (2)]
        
        if !FileManager.default.fileExists(atPath: fileUrl.path) { // [rd: { init FileManager.default, (let fileUrl).path } (2)]
            FileManager.default.createFile(atPath: fileUrl.path, contents: nil, attributes: nil) // [rd: { (let fileUrl).path, init FileManager.default } (2)]
        }
        
        return try? FileHandle(forUpdating: fileUrl) // [rd: { let fileUrl } (1)]
    } // [lines: 89]
    
    // [dd: 3]
    private static func getLogDirectoryUrl() -> URL {
        let libraryDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first! // [rd: { init FileManager.default } (1)]
        
        return libraryDirectory.appendingPathComponent(Self.logDirectoryName, isDirectory: true) // [rd: { let libraryDirectory, Self.logDirectoryName } (2)]
    } // [lines: 93]
    
    // [dd: 1]
    private static func getCurrentTimeString() -> String {
        self.dateFormatter.string(from: Date()) // [rd: { init dateFormatter } (1)]
    } // [lines: 96]
    
} // [lines: 97]

extension Logger : Archivable {
    
    // [dd: 2]
    func getArchivableUrl(_ completion: @escaping (URL?) -> Void) {
        // closure: [dd: 6]
        Logger.operationQueue.addOperation {  // [rd: { (init Logger).operationQueue, init completion } (2)]
            let logDirectoryUrl = Logger.getLogDirectoryUrl() // [rd: { init Logger } (1)]
            
            guard FileManager.default.fileExists(atPath: logDirectoryUrl.path) else { // [rd: { init FileManager.default, (let logDirectoryUrl).path } (2)]
                completion(nil) // [rd: { init completion } (1)]
                return
            }
            
            completion(logDirectoryUrl) // [rd: { init completion, let logDirectoryUrl } (2)]
        }
    }
} // [lines: 109]
