import Foundation

class DifyAPIService {
    
    private func formatJSON(_ jsonString: String) -> String {
         
        do {
            guard let jsonData = jsonString.data(using: .utf8) else {
                return "  " + jsonString
            }
            
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                let prettyJsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
                if let prettyPrintedString = String(data: prettyJsonData, encoding: .utf8) {
                     
                    let lines = prettyPrintedString.components(separatedBy: "\n")
                    let indentedLines = lines.map { "  " + $0 }
                    return indentedLines.joined(separator: "\n")
                }
            }
        } catch {
             
            print("  [JSON formatting failed: \(error)]")
        }
        
         
        return "  " + jsonString.replacingOccurrences(of: "\n", with: "\n  ")
    }
     
    private var baseURL: String
    private let messagePath = "/chat-messages"
    
     
    private(set) var difyAPIKey: String
    private(set) var difyAppID: String
    
    init(apiKey: String, appID: String) {
         
        self.difyAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.difyAppID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.baseURL = ConfigManager.shared.difyBaseURL
        
        print("[DIFY] Initialized API service with API key: \(self.difyAPIKey)")
        print("[DIFY] Initialized API service with App ID: \(self.difyAppID)")
        print("[DIFY] Initialized API service with Base URL: \(self.baseURL)")
    }
    
     
    
    func sendMessageForSummary(text: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("[DIFY API] REQUEST START")
        print("[DIFY API] Timestamp: \(Date())")
        print("[DIFY API] Endpoint: \(baseURL + messagePath)")
        print("[DIFY API] API Key: \(difyAPIKey)")
        print("[DIFY API] Text length: \(text.count) characters")
        
         
        guard let url = URL(string: baseURL + messagePath) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
         
        let payload: [String: Any] = [
            "query": "Summarize the following text in clear, concise bullet points: \(text)",
            "inputs": [:],  
            "response_mode": "blocking",  
            "user": difyAppID,  
            "conversation_id": "",  
            "auto_generate_name": true  
             
        ]
        
         
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload),
              let payloadString = String(data: payloadData, encoding: .utf8) else {
            print("[DIFY API] Error: Failed to serialize request payload")
            DispatchQueue.main.async {
                completion(.failure(APIError.parsingError))
            }
            return
        }
        
         
        print("[DIFY API] REQUEST PAYLOAD:")
        print(self.formatJSON(payloadString))
        
         
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payloadData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(difyAPIKey)", forHTTPHeaderField: "Authorization")
        
         
        print("[DIFY API] Authorization: Bearer \(difyAPIKey)")
        
         
        request.setValue(difyAppID, forHTTPHeaderField: "X-App-ID")
        
         
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[DIFY API] Network error occurred")
                print("[DIFY API] Details: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(APIError.networkError))
                }
                return
            }
            
             
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[DIFY API] Invalid HTTP response")
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            print("[DIFY API] RESPONSE STATUS: \(httpResponse.statusCode) - \((200...299).contains(httpResponse.statusCode) ? "SUCCESS" : "ERROR")")
            print("[DIFY API] Timestamp: \(Date())")
            
            print("[DIFY API] RESPONSE HEADERS:")
            httpResponse.allHeaderFields.forEach { key, value in
                print("[DIFY API] \(key): \(value)")
            }
            
            
             
            if (200...299).contains(httpResponse.statusCode) == false {
                let responseDetails = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                print("[DIFY API] HTTP ERROR \(httpResponse.statusCode)")
                print("[DIFY API] Details: \(responseDetails)")
                
                 
                switch httpResponse.statusCode {
                case 400:
                     
                    if responseDetails.contains("provider_quota_exceeded") {
                        DispatchQueue.main.async {
                            completion(.failure(APIError.providerQuotaExceeded))
                        }
                    } else {
                         
                        DispatchQueue.main.async {
                            completion(.failure(APIError.httpError(statusCode: httpResponse.statusCode, details: responseDetails)))
                        }
                    }
                case 404:
                     
                    DispatchQueue.main.async {
                        completion(.failure(APIError.resourceNotFound))
                    }
                default:
                     
                    DispatchQueue.main.async {
                        completion(.failure(APIError.httpError(statusCode: httpResponse.statusCode, details: responseDetails)))
                    }
                }
                return
            }
            
             
            guard let data = data else {
                print("[DIFY API] Error: No data received from server")
                DispatchQueue.main.async {
                    completion(.failure(APIError.invalidResponse))
                }
                return
            }
            
             
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to convert to string"
            print("[DIFY API] RESPONSE BODY:")
            print(self.formatJSON(responseString))
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                     
                    if let answer = json["answer"] as? String {
                        print("[DIFY API] Response successfully parsed")
                        DispatchQueue.main.async {
                            completion(.success(answer))
                        }
                        return
                    }
                    
                     
                    if let messages = json["data"] as? [[String: Any]],
                       let firstMessage = messages.first,
                       let answer = firstMessage["answer"] as? String {
                        print("[DIFY API] Response successfully parsed from message data")
                        DispatchQueue.main.async {
                            completion(.success(answer))
                        }
                        return
                    }
                    
                     
                    print("[DIFY API] Error: Unsupported response format")
                    print("[DIFY API] No 'answer' field found in response")
                    DispatchQueue.main.async {
                        completion(.failure(APIError.invalidResponse))
                    }
                } else {
                    print("[DIFY API] Error: Unable to parse response data as JSON")
                    DispatchQueue.main.async {
                        completion(.failure(APIError.invalidResponse))
                    }
                }
            } catch {
                print("[DIFY API] Error: JSON parsing failed")
                print("[DIFY API] Details: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(APIError.parsingError))
                }
            }
        }
         
        task.resume()
    }
    
     
    
    enum APIError: Error {
        case invalidURL
        case httpError(statusCode: Int, details: String)
        case networkError
        case invalidResponse
        case parsingError
        case providerQuotaExceeded
        case unavailableApp
        case resourceNotFound
        
        var localizedDescription: String {
            switch self {
            case .invalidURL:
                return "Invalid URL provided"
            case .httpError(let statusCode, let details):
                return "HTTP error \(statusCode): \(details)"
            case .networkError:
                return "Network connection failed"
            case .invalidResponse:
                return "Invalid response from server"
            case .parsingError:
                return "Failed to parse server response"
            case .providerQuotaExceeded:
                return "API quota exceeded"
            case .unavailableApp:
                return "Application unavailable"
            case .resourceNotFound:
                return "Requested resource not found"
            }
        }
    }
}
