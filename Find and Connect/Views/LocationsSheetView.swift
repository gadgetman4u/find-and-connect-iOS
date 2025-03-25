import SwiftUI

struct LocationsSheetView: View {
    @ObservedObject var beaconManager: BeaconScanManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                ForEach(beaconManager.discoveredBeacons, id: \.self) { beacon in
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(beacon)
                                .font(.system(size: 16, weight: .medium))
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 15) {
                            if let rssi = beaconManager.getRSSI(for: beacon) {
                                HStack(spacing: 4) {
                                    Image(systemName: "wifi")
                                    Text("\(rssi) dBm")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.blue.opacity(0.1))
                                )
                            }
                            
                            if beacon == beaconManager.nearestBeaconId {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .refreshable {
                // This will allow the user to pull to refresh the list
                print("Refreshing beacon list")
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Discovered Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
} 