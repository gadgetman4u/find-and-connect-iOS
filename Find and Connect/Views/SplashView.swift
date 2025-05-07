import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    let appVersion: String
    
    var body: some View {
        if isActive {
            ContentView(appVersion: appVersion)
        } else {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.green.opacity(0.8), Color.blue.opacity(0.9)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    VStack {
                        Image(systemName: "wave.3.right.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                        
                        Text("Find & Connect")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .scaleEffect(size)
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 1.2)) {
                            self.size = 0.9
                            self.opacity = 1.0
                        }
                    }
                    
                    Spacer()
                    
                    HStack {
                        Image("dpi_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .padding(.horizontal)
                        
                        
                        Image("SRI2025_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .padding(.horizontal)
                    }
                }
                
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
} 

#Preview {
    SplashView(appVersion: "2.0")
}
