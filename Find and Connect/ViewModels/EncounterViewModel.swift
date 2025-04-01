//
//  EncounterViewModel.swift
//  Find and Connect
//
//  Created by Billy Huang on 2025/4/1.
//

import Foundation

class EncounterViewModel: ObservableObject {
    
    let host = "http://localhost:8081/"
    
    func processEncounters(username: String) async throws -> [Encounter] {
        let endpoint = "\(host)/api/logs/process-encounters"
        
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Request parameters
        var parameters: [String: Any] = ["username": username]
        
        let jsonData = try JSONSerialization.data(withJSONObject: parameters)
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        //Parse the reponse
        do {
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            return try decoder.decode([Encounter], from: data)
        } catch {
            throw URLError(.badServerResponse)
        }
    }
    
    private func fetchEncounter() async throws -> [Encounter] {
        let endpoint = "http://localhost:8081/view/t"
    }
}
