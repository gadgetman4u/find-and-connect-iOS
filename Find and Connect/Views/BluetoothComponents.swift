import SwiftUI

// Helper view for the action buttons
struct ActionButtonsView: View {
    let isExpanded: Bool
    let color: Color
    let shareAction: () -> Void
    let uploadAction: () -> Void
    let toggleAction: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            if isExpanded {
                // Share button
                Button(action: shareAction) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(color))
                }
                .transition(.scale.combined(with: .opacity))
                
                // Upload button
                Button(action: uploadAction) {
                    Image(systemName: "icloud.and.arrow.up")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(color))
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Toggle actions button
            Button(action: toggleAction) {
                Image(systemName: isExpanded ? "xmark" : "ellipsis")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(color))
            }
            .padding(.trailing, 8)
        }
    }
}

// Helper view for log buttons
struct LogButtonView: View {
    let title: String
    let iconName: String
    let backgroundColor: Color
    let foregroundColor: Color
    let onClick: () -> Void
    
    var body: some View {
        Button(action: onClick) {
            HStack {
                Image(systemName: iconName)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(backgroundColor.opacity(0.1))
            .foregroundColor(foregroundColor)
            .cornerRadius(8)
        }
    }
} 