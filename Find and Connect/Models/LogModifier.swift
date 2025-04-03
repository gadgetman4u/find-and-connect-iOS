//
//  LogModifier.swift
//  Find and Connect
//
//  Created by Billy Huang on 2025/2/5.
//

import Foundation
import UIKit

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
    
    func uploadLogToServer(userId: String, completion: @escaping (Bool, String?) -> Void) {
        // Debug prints
        print("⬆️ Starting upload for \(isHeardSet ? "HeardLog" : "TellLog")")
        print("📋 User ID: \(userId)")
        print("👤 Username: \(username)")
        print("📁 Log content length: \(readLogFile()?.count ?? 0) characters")
        
        // Use existing readLogFile function to get the log content
        guard let logContent = readLogFile(), !logContent.isEmpty else {
            completion(false, "Log file is empty or cannot be read")
            return
        }
        
        // Make sure username is set
        guard !username.isEmpty else {
            completion(false, "Username is not set. Cannot upload log.")
            return
        }
        
        // Format the log content for server requirements
        let formattedContent = formatLogForServer()
        guard !formattedContent.isEmpty else {
            completion(false, "Could not format log content")
            return
        }
        
        // Set up the request
        guard let url = URL(string: "http://192.168.1.xxx:8081/api/logs/upload") else {
            completion(false, "Invalid server URL")
            return
        }
        
        // Create multipart request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        // Add userId
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"userId\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(userId)\r\n".data(using: .utf8)!)
        
        // Add username
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"username\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(username)\r\n".data(using: .utf8)!)
        
        // Add logType
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"logType\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(isHeardSet ? "heardLog" : "tellLog")\r\n".data(using: .utf8)!)
        
        // Add file - directly from formatted content
        let filename = isHeardSet ? "heardLog_\(username).txt" : "tellLog_\(username).txt"
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: text/plain\r\n\r\n".data(using: .utf8)!)
        data.append(formattedContent.data(using: .utf8)!)
        data.append("\r\n".data(using: .utf8)!)
        
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Create upload task
        let task = URLSession.shared.uploadTask(with: request, from: data) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "Upload error: \(error.localizedDescription)")
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(false, "Invalid server response")
                }
                return
            }
            
            // Print the response for debugging
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Server response: \(responseString)")
            }
            
            if httpResponse.statusCode == 201 {
                DispatchQueue.main.async {
                    completion(true, "Log uploaded successfully")
                }
            } else {
                var errorMessage = "Upload failed with status code: \(httpResponse.statusCode)"
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    errorMessage += "\nServer response: \(responseString)"
                }
                DispatchQueue.main.async {
                    completion(false, errorMessage)
                }
            }
        }
        
        task.resume()
    }
    
    // Helper method to format log data in the format expected by the server
    private func formatLogForServer() -> String {
        guard let csvContent = try? String(contentsOf: logfileURL, encoding: .utf8) else {
            return ""
        }
        
        var formattedLog = ""
        let lines = csvContent.components(separatedBy: "\n")
        
        for line in lines {
            if line.isEmpty { continue }
            
            let parts = line.components(separatedBy: ",")
            if parts.count >= 4 {
                if isHeardSet && parts.count >= 5 {
                    // Format: timestamp,eid,locationId,rssi,username
                    // Server expects: "EID: eid, Location: locationId, RSSI: rssi, Time: timestamp, Username: username"
                    let timestamp = parts[0]
                    let eid = parts[1]
                    let location = parts[2]
                    let rssi = parts[3]
                    let username = parts[4]
                    
                    let formattedDate = formatTimestampForServer(timestamp)
                    formattedLog += "EID: \(eid), Location: \(location), RSSI: \(rssi), Time: \(formattedDate), Username: \(username)\n"
                } else if !isHeardSet {
                    // Format: timestamp,eid,username,locationId
                    // Server expects: "EID: eid, Location: locationId, Time: timestamp, Username: username"
                    let timestamp = parts[0]
                    let eid = parts[1]
                    let username = parts[2]
                    let location = parts[3]
                    
                    let formattedDate = formatTimestampForServer(timestamp)
                    formattedLog += "EID: \(eid), Location: \(location), Time: \(formattedDate), Username: \(username)\n"
                }
            }
        }
        
        return formattedLog
    }
    
    private func formatTimestampForServer(_ timestamp: String) -> String {
        // Convert HH:mm:ss.microseconds to YYYY-MM-DD-HH:mm:ss format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let currentDate = dateFormatter.string(from: Date())
        
        // Take just the HH:mm:ss part from the timestamp
        let timeParts = timestamp.components(separatedBy: ".")
        let timeComponent = timeParts.first ?? "00:00:00"
        
        return "\(currentDate)-\(timeComponent)"
    }
    
    func deleteLogFromServer(logId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "http://localhost:8081/api/logs/\(logId)") else {
            completion(false, "Invalid server URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "Delete error: \(error.localizedDescription)")
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(false, "Invalid server response")
                }
                return
            }
            
            if httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    completion(true, "Log deleted successfully")
                }
            } else {
                var errorMessage = "Delete failed with status code: \(httpResponse.statusCode)"
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    errorMessage += "\nServer response: \(responseString)"
                }
                DispatchQueue.main.async {
                    completion(false, errorMessage)
                }
            }
        }
        
        task.resume()
    }
    
    func processEncounters(username: String, targetUsername: String? = nil, completion: @escaping (Bool, String?, Int) -> Void) {
        guard let url = URL(string: "http://localhost:8081/api/logs/process-encounters") else {
            completion(false, "Invalid server URL", 0)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the request body
        var bodyDict: [String: Any] = ["username": username]
        if let targetUsername = targetUsername {
            bodyDict["targetUsername"] = targetUsername
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: bodyDict)
            request.httpBody = jsonData
        } catch {
            completion(false, "Error creating request: \(error.localizedDescription)", 0)
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "Process error: \(error.localizedDescription)", 0)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(false, "Invalid server response", 0)
                }
                return
            }
            
            if httpResponse.statusCode == 200, let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = json["message"] as? String,
                       let encounters = json["encounters"] as? Int {
                        DispatchQueue.main.async {
                            completion(true, message, encounters)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(false, "Invalid response format", 0)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(false, "Error parsing response: \(error.localizedDescription)", 0)
                    }
                }
            } else {
                var errorMessage = "Process failed with status code: \(httpResponse.statusCode)"
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    errorMessage += "\nServer response: \(responseString)"
                }
                DispatchQueue.main.async {
                    completion(false, errorMessage, 0)
                }
            }
        }
        
        task.resume()
    }
}

