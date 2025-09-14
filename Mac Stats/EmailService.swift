//
//  EmailService.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import Foundation

class EmailService {
    static let shared = EmailService()
    
    private init() {}
    
    func sendMailjetEmail(
        apiKey: String,
        apiSecret: String,
        fromEmail: String,
        fromName: String,
        toEmail: String,
        subject: String,
        message: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Create the Mailjet API request
        let url = URL(string: "https://api.mailjet.com/v3.1/send")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set authorization header
        let authString = "\(apiKey):\(apiSecret)"
        let authData = authString.data(using: .utf8)!
        let base64AuthString = authData.base64EncodedString()
        request.setValue("Basic \(base64AuthString)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the request body
        let requestBody: [String: Any] = [
            "Messages": [
                [
                    "From": [
                        "Email": fromEmail,
                        "Name": fromName
                    ],
                    "To": [
                        [
                            "Email": toEmail
                        ]
                    ],
                    "Subject": subject,
                    "TextPart": message
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Send the request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "EmailService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            if httpResponse.statusCode == 200 {
                completion(.success("Email sent successfully"))
            } else {
                let errorMessage = "HTTP Error \(httpResponse.statusCode)"
                completion(.failure(NSError(domain: "EmailService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            }
        }.resume()
    }
    
    func sendTestEmail(
        apiKey: String,
        apiSecret: String,
        fromEmail: String,
        fromName: String,
        toEmail: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let subject = "Mac Stats - Email Test"
        let message = """
        This is a test email from Mac Stats.
        
        If you receive this email, your email notifications are configured correctly.
        
        Sent at: \(Date().formatted(date: .complete, time: .complete))
        """
        
        sendMailjetEmail(
            apiKey: apiKey,
            apiSecret: apiSecret,
            fromEmail: fromEmail,
            fromName: fromName,
            toEmail: toEmail,
            subject: subject,
            message: message,
            completion: completion
        )
    }
}