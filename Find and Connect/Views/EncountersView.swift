import SwiftUI

struct EncountersView: View {
    @Environment(\.dismiss) private var dismiss
    let response: UploadResponse
    let logType: LogType
    let currentUsername: String
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Header with summary
                summaryHeader
                
                // List of encounters
                encountersList
                
                Spacer()
            }
            .padding()
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
        ScrollView {
            VStack(spacing: 12) {
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

struct EncountersView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEncounters = [
            Encounter(
                user1: "Alice",
                user2: "Bob",
                startTime: "2023-04-01 13:45:00",
                endTime: "2023-04-01 14:15:00",
                encounterLocation: "Conference Room",
                encounterDuration: 1800
            ),
            Encounter(
                user1: "Alice",
                user2: "Charlie",
                startTime: "2023-04-01 15:00:00",
                endTime: "2023-04-01 15:10:00",
                encounterLocation: "Kitchen",
                encounterDuration: 600
            )
        ]
        
        let response = UploadResponse(
            message: "Log processed successfully",
            encounters: sampleEncounters
        )
        
        return EncountersView(response: response, logType: .tellLog, currentUsername: "Alice")
    }
} 
