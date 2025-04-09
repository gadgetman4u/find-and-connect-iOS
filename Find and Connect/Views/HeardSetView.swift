import SwiftUI

struct HeardSetView: View {
    @Environment(\.dismiss) private var dismiss
    let logContents: String
    var onClear: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                if logContents.isEmpty {
                    Text("No entries in HeardSet log")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                                   ScrollView {
                                       Text(logContents)
                                           .font(.system(size: 8, design: .monospaced))
                                           .padding()
                                           .frame(maxWidth: .infinity, alignment: .leading)
                                           .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("HeardSet Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        onClear()
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
} 
