//
//  LoginView.swift
//  Find and Connect
//
//  Created by Billy Huang on 2025/2/4.
//

import Foundation
import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var username: String
    @State private var inputName: String = ""
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.black.opacity(0.9)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Welcome")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                VStack(spacing: 20) {
                    TextField("Enter your name", text: $inputName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 18))
                        .padding(.horizontal)
                        .autocapitalization(.words)
                    
                    Button(action: {
                        if !inputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            username = inputName
                            isLoggedIn = true
                            // save to UserDefaults
                            UserDefaults.standard.set(inputName, forKey: "username")
                            UserDefaults.standard.set(true, forKey: "isLoggedIn")
                        }
                    }) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.white.opacity(0.2))
                            )
                            .padding(.horizontal)
                    }
                    .disabled(inputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.15))
                )
                .padding()
            }
        }
    }
}


