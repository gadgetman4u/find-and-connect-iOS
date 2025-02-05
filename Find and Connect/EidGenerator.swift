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
        return eid;
    }
    
    func generateEid() -> String {
        eid = UUID().uuidString.lowercased() //generate a random UUID
        print("Generated new EID: \(eid)")
        return eid
    }
}
