import SwiftUI

struct EncountersView: View {
    @Environment(\.dismiss) private var dismiss
    let response: UploadResponse
    let logType: LogType
    let currentUsername: String
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header with summary
                    summaryHeader
                    
                    // List of encounters
                    encountersList
                    
                    // New section for other users
                    if let otherUsers = response.otherUsers, !otherUsers.isEmpty {
                        otherUsersSection
                    }
                    
                    // New section for log details
                    if let log = response.log {
                        logDetailsSection(log: log)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Encounters")
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
            
            if let encounters = response.encounters, !encounters.isEmpty {
                ForEach(encounters, id: \.self) { encounter in
                    EncounterCard(
                        encounter: encounter,
                        logType: logType,
                        currentUsername: currentUsername
                    )
                }
            } else {
                Text("No encounters found")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    // New section for other users
    private var otherUsersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("People You've Met")
                .font(.headline)
                .padding(.vertical, 4)
            
            ForEach(response.otherUsers!) { user in
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
    let logType: LogType
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
