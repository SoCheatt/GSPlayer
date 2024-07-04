//
//  VideoCacheManager.swift
//  GSPlayer
//
//  Created by Gesen on 2019/4/20.
//  Copyright © 2019 Gesen. All rights reserved.
//

import Foundation

private var directory = NSTemporaryDirectory().appendingPathComponent("GSPlayer")
private var expirationDate: Date? = Calendar.current.date(byAdding: .day, value: 7, to: Date())

public enum VideoCacheManager {
    
    public static func configCacheDirectory(path: String) {
        directory = path
    }
    
    public static func configExpirationDate(_ expiration: GSExpiration) {
        expirationDate = expiration.estimatedExpirationSince(Date())
    }
    
    public static func getExpirationDate() -> Date? {
        expirationDate
    }
    
    public static func cachedFilePath(for url: URL) -> String {
        return directory
            .appendingPathComponent(url.absoluteString.md5)
            .appendingPathExtension(url.pathExtension)!
    }
    
    public static func cachedConfiguration(for url: URL) throws -> VideoCacheConfiguration {
        return try VideoCacheConfiguration
            .configuration(for: cachedFilePath(for: url))
    }
    
    public static func calculateCachedSize() -> UInt {
        let fileManager = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey]
        
        let fileContents = (try? fileManager.contentsOfDirectory(at: URL(fileURLWithPath: directory), includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles)) ?? []
        
        return fileContents.reduce(0) { size, fileContent in
            guard
                let resourceValues = try? fileContent.resourceValues(forKeys: resourceKeys),
                resourceValues.isDirectory != true,
                let fileSize = resourceValues.totalFileAllocatedSize
                else { return size }
            
            return size + UInt(fileSize)
        }
    }
    
    public static func cleanAllCache() throws {
        let fileManager = FileManager.default
        let fileContents = try fileManager.contentsOfDirectory(atPath: directory)
        
        for fileContent in fileContents {
            let filePath = directory.appendingPathComponent(fileContent)
            try fileManager.removeItem(atPath: filePath)
        }
    }
    
}


extension VideoCacheManager {
    public static func clearExpiredCache() {
        let urls = try? allFileURLs(for: [.contentModificationDateKey])
        
        let expiredFile = urls?.filter({ fileURL in
            if fileURL.pathExtension != "mp4" { return false }
            
            guard let expiredDate = fileModificationDate(path: fileURL.path) else {
                return false
            }
            
            return expiredDate < Date()
        })
        
        expiredFile?.forEach({ expiredFile in
            try? FileManager.default.removeItem(at: expiredFile)

            // Remove cfg file
            let urlString = expiredFile.path + ".cfg"
            let url = URL(fileURLWithPath: urlString)
            
            if FileManager.default.fileExists(atPath: urlString) {
                try? FileManager.default.removeItem(at: url)
            }
        })
    }
    
    private static func allFileURLs(for propertyKeys: [URLResourceKey]) throws -> [URL] {
        let fileManager = FileManager.default
        let directoryURL = URL(fileURLWithPath: directory)
        
        guard let directoryEnumerator = fileManager.enumerator(
            at: directoryURL, 
            includingPropertiesForKeys: propertyKeys,
            options: .skipsHiddenFiles) else {
            throw GSPlayerError(message: "Unable to find directory")
        }
        
        guard let urls = directoryEnumerator.allObjects as? [URL] else {
            throw GSPlayerError(message: "Invalid file")
        }
        
        return urls
    }
    
    private static func fileModificationDate(path: String) -> Date? {
        let url = URL(fileURLWithPath: path)
        
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: url.path)
            return (attr[FileAttributeKey.modificationDate] as? Date)
        } catch {
            return nil
        }
    }
    
}

struct GSPlayerError: Error {
    var message: String
}


extension Date {
    func localDate() -> Date {
        let timeZoneOffset = Double(TimeZone.current.secondsFromGMT(for: self))
        guard let localDate = Calendar.current.date(byAdding: .second, value: Int(timeZoneOffset), to: self) else {return Date()}

        return localDate
    }
}


struct TimeConstants {
    static let secondsInOneDay = 86_400
}

public enum GSExpiration {
    /// The item never expires.
    case never
    /// The item expires after a time duration of given seconds from now.
    case seconds(TimeInterval)
    /// The item expires after a time duration of given days from now.
    case days(Int)
    /// The item expires after a given date.
    case date(Date)
    /// Indicates the item is already expired. Use this to skip cache.
    case expired
    
    public func estimatedExpirationSince(_ date: Date) -> Date {
        switch self {
        case .never: return .distantFuture
        case .seconds(let seconds):
            return date.addingTimeInterval(seconds)
        case .days(let days):
            let duration: TimeInterval = TimeInterval(TimeConstants.secondsInOneDay) * TimeInterval(days)
            return date.addingTimeInterval(duration)
        case .date(let ref):
            return ref
        case .expired:
            return .distantPast
        }
    }
}
