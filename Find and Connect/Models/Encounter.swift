//
//  Encounter.swift
//  Find and Connect
//
//  Created by Billy Huang on 2025/4/1.
//

import Foundation

// data structure is based from MongoDB data schema
// if need to make changes to this, change MongoDB first and then here
struct UploadResponse: Codable {
    let message: String
    let log: LogInfo?
    let encounters: [Encounter]?
    let otherUsers: [OtherUser]?
    
    struct LogInfo: Codable {
        let filename: String
        let originalName: String
        let path: String
        let size: Int
        let username: String
        let email: String
        let logType: String
        let processed: Bool
        let _id: String
        let uploadDate: String
        let __v: Int
    }
}

struct ProcessResponse: Codable {
    let message: String
    let encountersDetected: Int
    let encountersSavedToDatabase: Int
    let encountersAfterDeduplication: Int
    let explanation: String
}

struct UserEncountersResponse: Codable {
    let message: String
    let encounters: [Encounter]
    let success: Bool
}

struct Encounter: Codable {
    let user1: String
    let user2: String
    let startTime: String
    let endTime: String
    let encounterLocation: String
    let encounterDuration: Int
    let _id: String?
    let otherUser: OtherUser
}

struct OtherUser: Codable, Identifiable {
    let username: String
    let email: String
    let encounters: Int?
    
    var id: String { username }
}


