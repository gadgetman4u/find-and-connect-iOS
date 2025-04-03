//
//  Encounter.swift
//  Find and Connect
//
//  Created by Billy Huang on 2025/4/1.
//

import Foundation

struct UploadResponse: Codable {
    let message: String
    let encounters: [Encounter]?
}

struct Encounter: Codable {
    let user1: String
    let user2: String
    let startTime: String
    let endTime: String
    let encounterLocation: String
    let encounterDuration: Int
}

