import SwiftUI

struct EncountersView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Support both response types
    var uploadResponse: UploadResponse?
    var userEncountersResponse: UserEncountersResponse?
    
    // Common parameters
    let logType: LogType?
    let currentUsername: String
    
    // Initialize with an UploadResponse (from log uploads)
    init(response: UploadResponse, logType: LogType, currentUsername: String) {
        self.uploadResponse = response
        self.userEncountersResponse = nil
        self.logType = logType
        self.currentUsername = currentUsername
    }
    
    // Initialize with a UserEncountersResponse (from getEncounters)
    init(userResponse: UserEncountersResponse, username: String) {
        self.uploadResponse = nil
        self.userEncountersResponse = userResponse
        self.logType = nil
        self.currentUsername = username
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header with summary
                    summaryHeader
                    
                    // List of encounters
                    encountersList
                    
                    // Only show these sections for upload responses
                    if let response = uploadResponse {
                        // New section for other users
                        if let otherUsers = response.otherUsers, !otherUsers.isEmpty {
                            otherUsersSection
                        }
                        
                        // New section for log details
                        if let log = response.log {
                            logDetailsSection(log: log)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(uploadResponse != nil ? "Encounters" : "My Encounters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let response = uploadResponse {
                // Upload response header
                Text("Log Upload Successful")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Text(response.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                
                Text("Found \(response.encounters?.count ?? 0) encounters")
                    .font(.title3)
                    .fontWeight(.medium)
            } else if let response = userEncountersResponse {
                // User encounters response header
                Text("User Encounters")
                    .font(.headline)
                    .foregroundColor(.teal)
                
                Text(response.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                
                Text("Found \(response.encounters.count) encounters")
                    .font(.title3)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var encountersList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Encounters")
                .font(.headline)
                .padding(.vertical, 4)
            
            if let response = uploadResponse, let encounters = response.encounters, !encounters.isEmpty {
                // Display upload response encounters
                ForEach(encounters, id: \.self) { encounter in
                    EncounterCard(
                        encounter: encounter,
                        logType: logType,
                        currentUsername: currentUsername
                    )
                }
            } else if let response = userEncountersResponse, !response.encounters.isEmpty {
                // Display user encounters response
                ForEach(response.encounters, id: \._id) { encounter in
                    UserEncounterCard(
                        encounter: encounter,
                        currentUsername: currentUsername
                    )
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    
                    Text("No encounters found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("When you have encounters with other users, they will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    // New section for other users
    private var otherUsersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("People You've Met")
                .font(.headline)
                .padding(.vertical, 4)
            
            ForEach(uploadResponse!.otherUsers!) { user in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.username)
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text(user.email)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(user.encounters) \(user.encounters == 1 ? "encounter" : "encounters")")
                        .font(.system(size: 14))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(10)
            }
        }
    }
    
    // New section for log details
    private func logDetailsSection(log: UploadResponse.LogInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Log Details")
                .font(.headline)
                .padding(.vertical, 4)
            
            Group {
                InfoRow(label: "File", value: log.originalName)
                InfoRow(label: "Size", value: "\(log.size) bytes")
                InfoRow(label: "User", value: log.username)
                InfoRow(label: "Type", value: log.logType)
                InfoRow(label: "Uploaded", value: formatDate(log.uploadDate))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Convert ISO date string to readable format
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// Helper view for displaying log info rows
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 70, alignment: .leading)
            
            Text(value)
                .font(.system(size: 14))
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct EncounterCard: View {
    let encounter: Encounter
    let logType: LogType?
    let currentUsername: String
    
    private var otherPersonName: String {
        if currentUsername == encounter.user1 {
            return encounter.user2
        } else {
            return encounter.user1
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("With: \(otherPersonName)")
                    .font(.headline)
                
                Spacer()
                
                Text("\(encounter.encounterDuration) minute(s)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.orange)
                Text(encounter.encounterLocation)
                    .font(.subheadline)
            }
            
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.green)
                Text(formatDateRange(start: encounter.startTime, end: encounter.endTime))
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(12)
    }
    
    private func formatDateRange(start: String, end: String) -> String {
        // You could format this better if the date strings are parseable
        return "\(start) to \(end)"
    }
}

struct UserEncounterCard: View {
    let encounter: Encounter
    let currentUsername: String
    
    private var otherPersonName: String {
        if currentUsername == encounter.user1 {
            return encounter.user2
        } else {
            return encounter.user1
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("With: \(otherPersonName)")
                        .font(.headline)
                    
                    Text(encounter.otherUser.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(encounter.encounterDuration) minute(s)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.teal.opacity(0.8))
                    .cornerRadius(8)
            }
            
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.orange)
                Text(encounter.encounterLocation)
                    .font(.subheadline)
            }
            
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.green)
                Text(formatDate(encounter.startTime))
                    .font(.caption)
            }
            
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                Text("\(formatTime(encounter.startTime)) - \(formatTime(encounter.endTime))")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(12)
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Extract just the date part
        if let spaceIndex = dateString.firstIndex(of: " ") {
            return String(dateString[..<spaceIndex])
        }
        return dateString
    }
    
    private func formatTime(_ dateString: String) -> String {
        // Extract just the time part
        if let spaceIndex = dateString.firstIndex(of: " ") {
            return String(dateString[dateString.index(after: spaceIndex)...])
        }
        return dateString
    }
}

// Enable preview by making Encounter conform to Hashable
extension Encounter: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(user1)
        hasher.combine(user2)
        hasher.combine(startTime)
        hasher.combine(endTime)
    }
    
    static func == (lhs: Encounter, rhs: Encounter) -> Bool {
        return lhs.user1 == rhs.user1 &&
               lhs.user2 == rhs.user2 &&
               lhs.startTime == rhs.startTime &&
               lhs.endTime == rhs.endTime &&
               lhs.encounterLocation == rhs.encounterLocation
    }
}
