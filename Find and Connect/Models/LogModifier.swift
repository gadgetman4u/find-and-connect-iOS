//
//  LogModifier.swift
//  Find and Connect
//
//  Created by Billy Huang on 2025/2/5.
//

import Foundation

class LogModifier {
    var timestamp: TimeInterval
    var eid: String
    var username: String
    var locationId: String
    var rssi: NSNumber?
    
    private let logfileURL: URL
    private let isHeardSet: Bool
    
    init(isHeardSet: Bool = false) {
        self.timestamp = Date().timeIntervalSince1970
        self.eid = ""
        self.username = ""
        self.locationId = ""
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.logfileURL = documentsPath.appendingPathComponent(isHeardSet ? "heardSet.csv" : "tellSet.csv")
        self.isHeardSet = isHeardSet
        
        if !FileManager.default.fileExists(atPath: logfileURL.path) {
            try? "".write(to: logfileURL, atomically: true, encoding: .utf8)
            print("Created new \(isHeardSet ? "heardSet" : "tellSet") log file at: \(logfileURL.path)")
        }
    }
    
    // TellSet update and write functions
    func updateTellSetLog(eid: String, username: String, locationId: String) {
        self.timestamp = Date().timeIntervalSince1970
        self.eid = eid
        self.username = username
        self.locationId = locationId
        
        writeTellSetToCSV()
    }
    
    private func writeTellSetToCSV() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeString = formatter.string(from: Date(timeIntervalSince1970: timestamp))
        let microseconds = String(format: "%.6f", timestamp.truncatingRemainder(dividingBy: 1)).dropFirst()
        let preciseTime = timeString + microseconds
        
        let logEntry = "\(preciseTime),\(eid),\(username),\(locationId)\n"
        
        writeToFile(logEntry)
    }
    
    // HeardSet update and write functions
    func updateHeardSetLog(eid: String, locationId: String, rssi: NSNumber, username: String) {
        self.timestamp = Date().timeIntervalSince1970
        self.eid = eid
        self.locationId = locationId
        self.rssi = rssi
        self.username = username
        
        writeHeardSetToCSV()
    }
    
    private func writeHeardSetToCSV() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeString = formatter.string(from: Date(timeIntervalSince1970: timestamp))
        let microseconds = String(format: "%.6f", timestamp.truncatingRemainder(dividingBy: 1)).dropFirst()
        let preciseTime = timeString + microseconds
        
        // Format: timestamp,eid,location,rssi,username
        let logEntry = "\(preciseTime),\(eid),\(locationId),\(rssi?.stringValue ?? "N/A"),\(username)\n"
        
        writeToFile(logEntry)
    }
    
    private func writeToFile(_ logEntry: String) {
        if let fileHandle = try? FileHandle(forWritingTo: logfileURL) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(logEntry.data(using: .utf8) ?? Data())
            fileHandle.closeFile()
            print("📝 \(isHeardSet ? "HeardSet" : "TellSet") Entry: \(logEntry)")
        }
    }
    
    // Common functions remain the same
    func readLogFile() -> String? {
        return try? String(contentsOf: logfileURL, encoding: .utf8)
    }
    
    func clearLogFile() {
        try? "".write(to: logfileURL, atomically: true, encoding: .utf8)
        print("Cleared \(isHeardSet ? "heardSet" : "tellSet") log file")
    }
    
    func printLogFilePath() {
        print("📂 \(isHeardSet ? "HeardSet" : "TellSet") log file location: \(logfileURL.path)")
    }
    
    func getLogFileURL() -> URL {
        return logfileURL
    }
    
}

