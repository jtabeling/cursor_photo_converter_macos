//
//  Logger.swift
//  Photo Converter
//
//  Created for debugging conversion issues
//

import Foundation
import Photos

// Simple synchronous logger class (not an actor to avoid initialization issues)
class Logger {
    static let shared = Logger()
    
    private let logFileURL: URL
    private let dateFormatter: DateFormatter
    private var fileHandle: FileHandle?
    private let lock = NSLock()
    
    private init() {
        // Create log file in app's Application Support folder (sandbox-safe)
        let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appFolder = appSupportPath.appendingPathComponent("Photo Converter", isDirectory: true)
        
        // Create the directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true, attributes: nil)
        
        let logFileName = "PhotoConverter_\(Self.createTimestamp()).log"
        self.logFileURL = appFolder.appendingPathComponent(logFileName)
        
        // Date formatter for log timestamps
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        self.dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Create initial log file with header
        let header = """
        =====================================
        Photo Converter Log
        Started: \(dateFormatter.string(from: Date()))
        Log File: \(logFileURL.path)
        =====================================
        
        """
        
        // Create the file and keep a file handle open for immediate writes
        FileManager.default.createFile(atPath: logFileURL.path, contents: header.data(using: .utf8), attributes: nil)
        self.fileHandle = try? FileHandle(forWritingTo: logFileURL)
        if let fileHandle = self.fileHandle {
            fileHandle.seekToEndOfFile()
        }
        
        print("✅ Log file created at: \(logFileURL.path)")
    }
    
    private static func createTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }
    
    func log(_ message: String, level: LogLevel = .info) {
        lock.lock()
        defer { lock.unlock() }
        
        let timestamp = dateFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] [\(level.rawValue)] \(message)\n"
        
        // Write immediately to file handle
        if let data = logEntry.data(using: .utf8) {
            fileHandle?.write(data)
            // Force flush to disk immediately - critical for crash debugging
            try? fileHandle?.synchronize()
        }
        
        // Also print to console for Xcode debugging
        print(logEntry, terminator: "")
    }
    
    deinit {
        lock.lock()
        try? fileHandle?.close()
        lock.unlock()
    }
    
    func logError(_ message: String, error: Error? = nil) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }
        log(fullMessage, level: .error)
    }
    
    func logAssetInfo(_ asset: PHAsset) {
        let mediaTypeString: String
        switch asset.mediaType {
        case .image: mediaTypeString = "Image"
        case .video: mediaTypeString = "Video"
        case .audio: mediaTypeString = "Audio"
        default: mediaTypeString = "Unknown"
        }
        
        let info = """
        Asset Info:
          - Identifier: \(asset.localIdentifier)
          - Media Type: \(asset.mediaType.rawValue) (\(mediaTypeString))
          - Creation Date: \(asset.creationDate?.description ?? "nil")
          - Modification Date: \(asset.modificationDate?.description ?? "nil")
          - Duration: \(asset.duration)s
          - Pixel Size: \(asset.pixelWidth) x \(asset.pixelHeight)
          - Has Location: \(asset.location != nil)
          - Location: \(asset.location?.coordinate.latitude ?? 0), \(asset.location?.coordinate.longitude ?? 0)
        """
        log(info, level: .debug)
    }
    
    func logVideoResourceInfo(_ asset: PHAsset) {
        let resources = PHAssetResource.assetResources(for: asset)
        log("Asset has \(resources.count) resource(s):", level: .debug)
        for (index, resource) in resources.enumerated() {
            let info = """
              Resource[\(index)]:
                - Type: \(resource.type.rawValue)
                - Original Filename: \(resource.originalFilename)
                - UTI: \(resource.uniformTypeIdentifier)
            """
            log(info, level: .debug)
        }
    }
    
    func getLogFilePath() -> String {
        return logFileURL.path
    }
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
}

