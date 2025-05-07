//
//  APIManager.swift
//  Find and Connect
//
//  Created by Billy Huang on 2025/4/2.
//

import Foundation

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case networkError(Int, String)
}

enum LogType: String {
    case heardLog = "heardLog"
    case tellLog = "tellLog"
}

class APIManager {
//     Base URL
    private let baseURL = "https://dev-msn-encounters-be-f0d4fvbdeef7g8dj.centralus-01.azurewebsites.net/api"
//    private let baseURL = "http://10.194.213.230:8080/api" //format: http://<IP Address>:8080/api 
    
    // Singleton instance
    static let shared = APIManager()
    
    private init() {}
    
    func uploadLog(logContent: String, username: String, email: String, logType: LogType) async throws -> UploadResponse {
        print("⬆️ Starting upload for \(logType.rawValue)")
        print("👤 Username: \(username)")
        print("📧 Email: \(email)")
        
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
        
        // Add email field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"email\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(email)\r\n".data(using: .utf8)!)
        
        // Add logType field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"logType\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(logType.rawValue)\r\n".data(using: .utf8)!)
        
        // Add file field
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
            do {
                if let responseString = String(data: responseData, encoding: .utf8) {
                    print(responseString)
                } else {
                    print("Upload successful")
                }
                
                let decoder = JSONDecoder()
                let uploadResponse = try decoder.decode(UploadResponse.self, from: responseData)
                return uploadResponse
            }
            catch {
                print("Decoding Error: \(error)")
                throw APIError.decodingError(error)
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
    
    func processEncounters(for username: String) async throws -> ProcessResponse {
        // Trim whitespace from username to prevent "not found" errors
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Set up URL
        guard let encodedUsername = trimmedUsername.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/logs/process-encounters/\(encodedUsername)") else {
            print("⚠️ Error: Invalid URL for username: \(username)")
            throw URLError(.badURL)
        }
        
        print("🔄 Processing encounters for user: '\(trimmedUsername)'")
        print("🔗 URL: \(url.absoluteString)")
        
        // Set up URL Request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15 // Add a timeout to prevent hanging
        
        // Send the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Process the Response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📊 Response status code: \(httpResponse.statusCode)")
        
        // Check status codes
        if(httpResponse.statusCode == 200 || httpResponse.statusCode == 201) {
            do {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📝 Response data: \(responseString)")
                } else {
                    print("✅ Processing Successful")
                }
                
                let decoder = JSONDecoder()
                let processResponse = try decoder.decode(ProcessResponse.self, from: data)
                return processResponse
            } catch {
                print("⚠️ Decoding Error: \(error)")
                throw APIError.decodingError(error)
            }
        } else {
            let errorMessage = "Processing failed with status code: \(httpResponse.statusCode)"
            if let responseString = String(data: data, encoding: .utf8) {
                print("⚠️ API Error: \(errorMessage) - \(responseString)")
                throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "\(errorMessage) - \(responseString)"])
            } else {
                print("⚠️ API Error: \(errorMessage)")
                throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
        }
    }
    
    func getEncounters(for username: String) async throws -> UserEncountersResponse {
        // Trim whitespace from username to prevent "not found" errors
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Set up URL
        guard let encodedUsername = trimmedUsername.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/encounters/user-encounters/\(encodedUsername)") else {
            print("⚠️ Error: Invalid URL for username: \(username)")
            throw URLError(.badURL)
        }
        
        print("🔍 Requesting encounters for user: '\(trimmedUsername)'")
        print("🔗 URL: \(url.absoluteString)")
        
        // Set up URL Request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15 // Add a timeout to prevent hanging
        
        // Send the request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Process the Response
            guard let httpResponse = response as? HTTPURLResponse else {
                print("⚠️ Error: Invalid response type")
                throw URLError(.badServerResponse)
            }
            
            print("📊 Response status code: \(httpResponse.statusCode)")
            
            // Print response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📝 Response data: \(responseString)")
            }
            
            // Check status codes
            if(httpResponse.statusCode == 200) {
                do {
                    let decoder = JSONDecoder()
                    let encountersResponse = try decoder.decode(UserEncountersResponse.self, from: data)
                    print("✅ Successfully decoded \(encountersResponse.encounters.count) encounters")
                    return encountersResponse
                } catch {
                    print("⚠️ Decoding Error: \(error)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📝 Failed to decode response: \(responseString)")
                    }
                    throw APIError.decodingError(error)
                }
            } else {
                let errorMessage = "Failed to fetch encounters with status code: \(httpResponse.statusCode)"
                if let responseString = String(data: data, encoding: .utf8) {
                    print("⚠️ API Error: \(errorMessage) - \(responseString)")
                    throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "\(errorMessage) - \(responseString)"])
                } else {
                    print("⚠️ API Error: \(errorMessage)")
                    throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
            }
        } catch {
            print("⚠️ Network Error: \(error.localizedDescription)")
            throw error // Re-throw the error to be caught by the caller
        }
    }
}
