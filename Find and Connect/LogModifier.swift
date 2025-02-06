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
    
    private let logfileURL: URL
    
    init() {
        self.timestamp = Date().timeIntervalSince1970
        self.eid = ""
        self.username = ""
        self.locationId = ""
        
        // Get the documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.logfileURL = documentsPath.appendingPathComponent("tellSet.csv")
        
        // Create empty file if it doesn't exist (no headers needed)
        if !FileManager.default.fileExists(atPath: logfileURL.path) {
            try? "".write(to: logfileURL, atomically: true, encoding: .utf8)
            print("Created new tellSet log file at: \(logfileURL.path)")
        }
    }
    
    func updateLog(eid: String, username: String, locationId: String) {
        print("Updating log with EID: \(eid)") // Debug print
        self.timestamp = Date().timeIntervalSince1970
        self.eid = eid
        self.username = username
        self.locationId = locationId
        
        // Write to CSV file
        writeToCSV()
    }
    
    private func writeToCSV() {
        // Create precise timestamp format
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeString = formatter.string(from: Date(timeIntervalSince1970: timestamp))
        
        // Get microseconds
        let microseconds = String(format: "%.6f", timestamp.truncatingRemainder(dividingBy: 1))
            .dropFirst() // remove leading "0"
        
        // Combine time and microseconds
        let preciseTime = timeString + microseconds
        
        // Debug print
        print("Writing log entry with EID: \(eid)")
        
        // Make sure we're using the actual EID
        let logEntry = "\n\(preciseTime),\(eid),\(username),\(locationId)\n"
        
        if let fileHandle = try? FileHandle(forWritingTo: logfileURL) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(logEntry.data(using: .utf8) ?? Data())
            fileHandle.closeFile()
            print("📝 TellSet Entry: \(logEntry)")
            
            // Debug print the file contents
            if let contents = try? String(contentsOf: logfileURL, encoding: .utf8) {
                print("Current file contents:")
                print(contents)
            }
        } else {
            print("❌ Error: Could not write to log file")
        }
    }
    
    func getLogData() -> Data? {
        let tellSetData: [String: Any] = [
            "timestamp": timestamp,
            "eid": eid,
            "username": username,
            "locationId": locationId
        ]
        
        return try? JSONSerialization.data(withJSONObject: tellSetData)
    }
    
    // Helper method to get the current log file contents
    func readLogFile() -> String? {
        return try? String(contentsOf: logfileURL, encoding: .utf8)
    }
    
    // Helper method to clear the log file
    func clearLogFile() {
        try? "".write(to: logfileURL, atomically: true, encoding: .utf8)
        print("Cleared tellSet log file")
    }
    
    func printLogFilePath() {
        print("📂 TellSet log file location: \(logfileURL.path)")
    }
}

