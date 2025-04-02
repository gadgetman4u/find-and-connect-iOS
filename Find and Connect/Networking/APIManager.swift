//
//  APIManager.swift
//  Find and Connect
//
//  Created by Billy Huang on 2025/4/2.
//

import Foundation

enum LogType: String {
    case heardLog = "heardLog"
    case tellLog = "tellLog"
}

class APIManager {
    // Base URL
    private let baseURL = "http://localhost:8081/api"
    
    // Singleton instance
    static let shared = APIManager()
    
    private init() {}
    
    func uploadLog(logContent: String, username: String, logType: LogType) async throws -> String {
        print("⬆️ Starting upload for \(logType.rawValue)")
        print("👤 Username: \(username)")
        
        // Set up URL
        guard let url = URL(string: "\(baseURL)/logs/upload") else {
            throw URLError(.badURL)
        }
        
        // Set up URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add username field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"username\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(username)\r\n".data(using: .utf8)!)
        
        // Add logType field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"logType\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(logType.rawValue)\r\n".data(using: .utf8)!)
        
        // Add file field - this was incorrect in your implementation
        let filename = "\(logType.rawValue)_\(username).txt"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: text/plain\r\n\r\n".data(using: .utf8)!)
        body.append(logContent.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // End multipart form
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Set the HTTP body
        request.httpBody = body
        
        // Send the request
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        // Process the response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // Check for successful status codes
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            if let responseString = String(data: responseData, encoding: .utf8) {
                return responseString
            } else {
                return "Upload successful"
            }
        } else {
            let errorMessage = "Upload failed with status code: \(httpResponse.statusCode)"
            if let responseString = String(data: responseData, encoding: .utf8) {
                throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "\(errorMessage) - \(responseString)"])
            } else {
                throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
        }
    }
}
