//
//  SMTPClient.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import Foundation
import Network

class SMTPClient {
    private let hostname: String
    private let port: UInt16
    private var connection: NWConnection?
    
    init(hostname: String, port: UInt16) {
        self.hostname = hostname
        self.port = port
    }
    
    func connect(completion: @escaping (Result<Void, Error>) -> Void) {
        let parameters = NWParameters.tcp
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(hostname), port: NWEndpoint.Port(rawValue: port)!)
        
        connection = NWConnection(to: endpoint, using: parameters)
        
        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                completion(.success(()))
            case .failed(let error):
                completion(.failure(error))
            default:
                break
            }
        }
        
        connection?.start(queue: .global())
    }
    
    func sendCommand(_ command: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let connection = connection else {
            completion(.failure(NSError(domain: "SMTPClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected to server"])))
            return
        }
        
        let data = "\(command)\r\n".data(using: .utf8)!
        
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Read response
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                if let data = data, let response = String(data: data, encoding: .utf8) {
                    completion(.success(response))
                } else {
                    completion(.failure(NSError(domain: "SMTPClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to read response from server"])))
                }
            }
        })
    }
    
    func close() {
        connection?.cancel()
        connection = nil
    }
}