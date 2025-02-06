//
//  EidGenerator.swift
//  Find and Connect
//
//  Created by Billy Huang on 2025/2/5.
//

import Foundation

class EidGenerator {
    private var eid: String = ""

    func getEid() -> String {
        let uuid = UUID().uuidString
        print("Generated EID: \(uuid)") // Debug print
        return uuid
    }
    
    func generateEid() -> String {
        eid = UUID().uuidString.lowercased() //generate a random UUID
        print("Generated new EID: \(eid)")
        return eid
    }
}
