import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingCompleted: Bool
    @State private var currentPage = 0
    
    // Define onboarding pages
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            image: "wave.3.right.circle.fill",
            title: "Welcome to Find & Connect",
            description: "This app helps you track and discover encounters with other users at specific locations."
        ),
        OnboardingPage(
            image: "headphones",
            title: "HeardSet Logs",
            description: "Your device listens for nearby users and records their presence in your HeardSet log."
        ),
        OnboardingPage(
            image: "megaphone",
            title: "TellSet Logs",
            description: "Your device broadcasts your presence, allowing others to discover you in specific locations. This is stored in the TellSet log"
        ),
        OnboardingPage(
            image: "person.2.fill",
            title: "Discover Encounters",
            description: "Upload your logs to see who you've encountered, when, and where."
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.green.opacity(0.8), Color.blue.opacity(0.9)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        withAnimation {
                            isOnboardingCompleted = true
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                }
                
                // Card pager
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingCardView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                // Navigation buttons
                HStack {
                    // Back button (hide on first page)
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation {
                                currentPage -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .padding()
                            .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                    
                    // Next/Get Started button
                    Button(action: {
                        withAnimation {
                            if currentPage < pages.count - 1 {
                                currentPage += 1
                            } else {
                                isOnboardingCompleted = true
                            }
                        }
                    }) {
                        Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            .fontWeight(.semibold)
                            .padding()
                            .padding(.horizontal)
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(20)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }
}

struct OnboardingCardView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: page.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 150, height: 150)
                .foregroundColor(.white)
            
            Text(page.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(page.description)
                .font(.system(size: 18))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
}

struct OnboardingPage {
    let image: String
    let title: String
    let description: String
} 
