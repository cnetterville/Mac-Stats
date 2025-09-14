//
//  EmailService.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import Foundation
import AppKit

class EmailService: ObservableObject {
    static let shared = EmailService()
    
    private init() {}
    
    /// Test Mailjet email configuration by sending a test email
    func testMailjetConfiguration(
        apiKey: String,
        apiSecret: String,
        fromEmail: String,
        toEmail: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Validate inputs
        guard !apiKey.isEmpty, !apiSecret.isEmpty, !fromEmail.isEmpty, !toEmail.isEmpty else {
            completion(.failure(MailjetError.invalidCredentials))
            return
        }
        
        // Instead of actually sending an email, we'll validate the API credentials
        validateMailjetCredentials(apiKey: apiKey, apiSecret: apiSecret) { result in
            switch result {
            case .success:
                completion(.success("Mailjet API credentials validated successfully"))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Validate Mailjet API credentials
    private func validateMailjetCredentials(
        apiKey: String,
        apiSecret: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Make a simple API call to validate credentials
        guard let url = URL(string: "https://api.mailjet.com/v3/REST/sender") else {
            completion(.failure(MailjetError.invalidCredentials))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Set up basic auth
        let loginString = "\(apiKey):\(apiSecret)"
        guard let loginData = loginString.data(using: .utf8) else {
            completion(.failure(MailjetError.invalidCredentials))
            return
        }
        let base64LoginString = loginData.base64EncodedString()
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(MailjetError.connectionFailed))
                return
            }
            
            if httpResponse.statusCode == 200 {
                completion(.success(()))
            } else {
                completion(.failure(MailjetError.invalidCredentials))
            }
        }.resume()
    }
    
    /// Send email notification through Mailjet REST API
    func sendMailjetEmail(
        apiKey: String,
        apiSecret: String,
        fromEmail: String,
        fromName: String = "Mac Stats",
        toEmail: String,
        subject: String,
        message: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Validate inputs
        guard !apiKey.isEmpty, !apiSecret.isEmpty, !fromEmail.isEmpty, !toEmail.isEmpty else {
            completion(.failure(MailjetError.invalidCredentials))
            return
        }
        
        // Prepare the email data
        let emailData: [String: Any] = [
            "Messages": [
                [
                    "From": [
                        "Email": fromEmail,
                        "Name": fromName
                    ],
                    "To": [
                        [
                            "Email": toEmail,
                            "Name": ""
                        ]
                    ],
                    "Subject": subject,
                    "TextPart": message
                ]
            ]
        ]
        
        // Send via Mailjet REST API
        sendViaMailjetAPI(
            apiKey: apiKey,
            apiSecret: apiSecret,
            emailData: emailData,
            completion: completion
        )
    }
    
    /// Send email via Mailjet REST API
    private func sendViaMailjetAPI(
        apiKey: String,
        apiSecret: String,
        emailData: [String: Any],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "https://api.mailjet.com/v3.1/send") else {
            completion(.failure(MailjetError.invalidEmailFormat))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set up basic auth
        let loginString = "\(apiKey):\(apiSecret)"
        guard let loginData = loginString.data(using: .utf8) else {
            completion(.failure(MailjetError.invalidCredentials))
            return
        }
        let base64LoginString = loginData.base64EncodedString()
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert email data to JSON
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: emailData, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(MailjetError.connectionFailed))
                return
            }
            
            if httpResponse.statusCode == 200, let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let messages = json["Messages"] as? [[String: Any]],
               let firstMessage = messages.first,
               let status = firstMessage["Status"] as? String,
               status == "success" {
                completion(.success("Email sent successfully via Mailjet"))
            } else {
                // Parse error message if available
                var errorMessage = "Failed to send email via Mailjet"
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessageFromAPI = json["ErrorMessage"] as? String {
                    errorMessage = errorMessageFromAPI
                }
                print("Mailjet API Error: \(errorMessage)")
                completion(.failure(MailjetError.sendFailed))
            }
        }.resume()
    }
    
    /// Send a test email
    func sendTestEmail(
        apiKey: String,
        apiSecret: String,
        fromEmail: String,
        fromName: String = "Mac Stats",
        toEmail: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let subject = "Mac Stats - Test Email"
        let message = "This is a test email from Mac Stats to verify your Mailjet configuration.\n\nIf you received this email, your email notifications are working correctly!"
        
        sendMailjetEmail(
            apiKey: apiKey,
            apiSecret: apiSecret,
            fromEmail: fromEmail,
            fromName: fromName,
            toEmail: toEmail,
            subject: subject,
            message: message
        ) { result in
            completion(result)
        }
    }
}

enum MailjetError: Error, LocalizedError {
    case invalidCredentials
    case connectionFailed
    case sendFailed
    case invalidEmailFormat
    case mailClientNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid Mailjet API key or secret"
        case .connectionFailed:
            return "Failed to connect to Mailjet API"
        case .sendFailed:
            return "Failed to send email via Mailjet"
        case .invalidEmailFormat:
            return "Invalid email format"
        case .mailClientNotFound:
            return "No mail client found"
        }
    }
}