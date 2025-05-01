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
    @Binding var email: String
    @State private var inputName: String = ""
    @State private var inputEmail: String = ""
    @State private var showEmailError = false
    
    var isEmailValid: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: inputEmail)
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.green.opacity(0.8), Color.blue.opacity(0.9)]),
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
                    
                    TextField("Enter your email", text: $inputEmail)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 18))
                        .padding(.horizontal)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    
                    if showEmailError {
                        Text("Please enter a valid email address")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                    }
                    
                    Button(action: {
                        let isNameValid = !inputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        
                        if isNameValid && isEmailValid {
                            // Trim username and email before setting
                            let trimmedName = inputName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let trimmedEmail = inputEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            username = trimmedName
                            email = trimmedEmail
                            isLoggedIn = true
                            
                            // save to UserDefaults
                            UserDefaults.standard.set(trimmedName, forKey: "username")
                            UserDefaults.standard.set(trimmedEmail, forKey: "email")
                            UserDefaults.standard.set(true, forKey: "isLoggedIn")
                            showEmailError = false
                        } else if !isEmailValid {
                            showEmailError = true
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


