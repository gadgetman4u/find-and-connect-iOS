//
//  Encounter.swift
//  Find and Connect
//
//  Created by Billy Huang on 2025/4/1.
//

import Foundation

struct Encounter: Codable {
    let id_: String
    let user1: String
    let user2: String
    let heardLogId: String?
    let tellLogId: String?
    let location: String
    let startTime: Date
    let endTime: Date
    let duration: Int
    let detectionDate: Date?
    
}

