//
//  EidGenerator.swift
//  Find and Connect
//
//  Created by Billy Huang on 2025/2/5.
//

import Foundation
import CryptoKit  // For secure random number generation

class EidGenerator {
    private var eid: String
    
    init() {
        // Initialize eid by generating a new one
        eid = ""  // Initialize first
        eid = generateEid()  // Then generate in init
    }
    
    
    
    func getEid() -> String {
        return eid
    }
    
    func generateEid() -> String {
        // Generate UUID and truncate to desired length (32 chars)
        eid = String(UUID().uuidString.prefix(23))  // Will give format like "XXXXXXXX-XXXX-XXXX-XXXX" (23 characters)
        print("Generated new EID: \(eid)")
        return eid
    }
}
