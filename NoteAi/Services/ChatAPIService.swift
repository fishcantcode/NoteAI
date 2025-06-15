import Foundation
import Combine
import OSLog

class ChatAPIService {
    private let baseURL: String
    private let apiKey: String
    private let session: URLSession
    private let logger = Logger(subsystem: "com.NoteAi.ChatAPIService", category: "Networking")
    
     
    init(session: URLSession = .shared) {
        self.baseURL = ConfigManager.shared.difyBaseURL  
        
        self.apiKey = ConfigManager.shared.difyChatAPIKey  
        
        if self.apiKey.isEmpty {
            print("[ChatAPIService] Error: Dify API Key is missing. Please check your configuration.")
            logger.critical("Dify API key is empty. Ensure DIFY_API_KEY is set in Config.xcconfig and the file is included in the target, or ConfigManager provides a valid key.")
            fatalError("Dify API key is empty. Please check your ConfigManager or Config.xcconfig.")
        }
        
        self.session = session
        print("DEBUG: ChatAPIService initialized with BaseURL: \(self.baseURL), API Key: [REDACTED]")
        if baseURL.isEmpty {
            print("ERROR: ChatAPIService initialized with an EMPTY Base URL.")
            logger.critical("ChatAPIService initialized with an EMPTY Base URL. Ensure DIFY_BASE_URL is set in Config.xcconfig and the file is included in the target.")
        }
    }
    
    private func createRequest(for endpoint: String, method: String) -> URLRequest? {
        let fullPath = "\(baseURL)/\(endpoint)"
        
         
        print("DEBUG: Attempting to create URL with full path: \(fullPath)")
        
        guard let url = URL(string: fullPath) else {
            logger.error("Invalid URL constructed: \(self.baseURL)/\(endpoint)")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        logger.debug("\(method) request to \(url.absoluteString)")
        logger.debug("Headers: \(request.allHTTPHeaderFields?.description ?? "none")")
        
        return request
    }
    
    func getConversations() -> AnyPublisher<Data, APIError> {
        let userId = "user-123"  
        let endpoint = "conversations?user=\(userId)&limit=20"
        
        guard let request = createRequest(for: endpoint, method: "GET") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        print("DEBUG: Fetching conversations list")
        
        return session.dataTaskPublisher(for: request)
            .handleEvents(
                receiveSubscription: { _ in print("DEBUG: Starting getConversations request") },
                receiveOutput: { output in 
                    print("DEBUG: Received conversation list data of \(output.data.count) bytes")
                    print("DEBUG: Conversation list data: \(String(data: output.data, encoding: .utf8) ?? "Could not convert to string")")
                },
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        print("DEBUG: getConversations request completed successfully")
                    case .failure(let error):
                        print("DEBUG: getConversations request failed with error: \(error)")
                    }
                }
            )
            .mapError { error -> APIError in
                return .networkError(error)
            }
            .map { $0.data }
            .eraseToAnyPublisher()
    }
    
    func getMessages(conversationId: String) -> AnyPublisher<Data, APIError> {
        let userId = "user-123"  
        let endpoint = "messages?conversation_id=\(conversationId)&user=\(userId)&limit=50"
        
        print("DEBUG: Getting messages with endpoint: \(endpoint)")
        
        guard let request = createRequest(for: endpoint, method: "GET") else {
            print("DEBUG: Failed to create request for getting messages")
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        print("DEBUG: Fetching messages for conversation: \(conversationId)")
        
        return session.dataTaskPublisher(for: request)
            .handleEvents(
                receiveSubscription: { _ in print("DEBUG: Starting getMessages request for conversation \(conversationId)") },
                receiveOutput: { output in 
                    print("DEBUG: Received messages data of \(output.data.count) bytes for conversation \(conversationId)")
                    if let str = String(data: output.data, encoding: .utf8) {
                        print("DEBUG: Messages data for \(conversationId): \(str.prefix(500))...")
                    }
                },
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        print("DEBUG: getMessages request completed successfully for conversation \(conversationId)")
                    case .failure(let error):
                        print("DEBUG: getMessages request failed with error: \(error) for conversation \(conversationId)")
                    }
                }
            )
            .mapError { error -> APIError in
                return .networkError(error)
            }
            .map { $0.data }
            .eraseToAnyPublisher()
    }
    
    func sendChatMessage(query: String, userId: String = "user-123", conversationId: String? = nil, responseMode: String = "blocking", inputs: [String: String] = [:]) -> AnyPublisher<Data, APIError> {
        
        guard var request = createRequest(for: "chat-messages", method: "POST") else {
            print("DEBUG: Failed to create request for sending message")
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var body: [String: Any] = [
            "query": query,
            "user": userId,
            "response_mode": responseMode,
            "inputs": inputs 
        ]

        if let convId = conversationId, !convId.isEmpty {
            body["conversation_id"] = convId
            logger.debug("Sending message to existing conversation_id: \(convId)")
        } else {
             
             
            body["auto_generate_name"] = true 
            logger.debug("conversation_id is nil or empty. auto_generate_name=true. Attempting to create a new conversation.")
        }
        
         
        if let requestBodyData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
           let requestBodyString = String(data: requestBodyData, encoding: .utf8) {
            print("DEBUG: Request body: \(requestBodyString)")
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            logger.error("Failed to serialize request body: \(error.localizedDescription)")
            return Fail(error: APIError.encodingError(error)).eraseToAnyPublisher()
        }
        
        if responseMode == "blocking" {
             
            return session.dataTaskPublisher(for: request)
                .handleEvents(
                    receiveSubscription: { _ in print("DEBUG: Starting blocking sendChatMessage request") },
                    receiveOutput: { output in 
                        print("DEBUG: Received blocking response data of \(output.data.count) bytes")
                        if let str = String(data: output.data, encoding: .utf8) {
                            print("DEBUG: Blocking response data: \(str.prefix(500))...")
                        }
                    },
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            print("DEBUG: Blocking sendChatMessage request completed successfully")
                        case .failure(let error):
                            print("DEBUG: Blocking sendChatMessage request failed with error: \(error)")
                        }
                    }
                )
                .mapError { error -> APIError in
                    return .networkError(error)
                }
                .map { $0.data }
                .eraseToAnyPublisher()
        } else {
             
            request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
            
             
            let subject = PassthroughSubject<Data, APIError>()
            
            let task = session.dataTask(with: request) { data, response, error in
                 
                if let error = error {
                    print("DEBUG: Streaming request error: \(error.localizedDescription)")
                    subject.send(completion: .failure(.networkError(error)))
                    return
                }
                
                 
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    let responseBodyString = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No body"
                    print("DEBUG: Streaming request received non-OK HTTP status: \(httpResponse.statusCode), Body: \(responseBodyString)")
                    subject.send(completion: .failure(.serverError(statusCode: httpResponse.statusCode, message: "Streaming failed with status \(httpResponse.statusCode). Body: \(responseBodyString)")))
                    return
                }
                
                 
                if let data = data {
                     
                     
                     
                     
                     
                    subject.send(data)  
                }
            }
            task.resume()
            return subject.eraseToAnyPublisher()
        }
    }
    
     
    func createConversation(name: String) -> AnyPublisher<Data, APIError> {
        print("\n==== CREATING NEW CONVERSATION ====\n")
        
         
         
        
        print("DEBUG: Direct conversation creation isn't supported. Using chat-messages with auto naming instead.")
        
         
        guard var request = createRequest(for: "chat-messages", method: "POST") else {
            print("DEBUG: Failed to create request for new conversation via chat-messages")
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
         
        print("DEBUG: Conversation creation URL: \(request.url?.absoluteString ?? "unknown")")
        print("DEBUG: Request method: \(request.httpMethod ?? "unknown")")
        print("DEBUG: Request headers: \(request.allHTTPHeaderFields?.description ?? "none")")
        
         
         
        let firstMessage = "Hello! This is the first message for a new conversation named: " + name + ". Please respond to start our chat."
        
        print("DEBUG: Starting new conversation with first message: '\(firstMessage)'")
        
        let requestBody: [String: Any] = [
            "query": firstMessage,
            "user": "user-123",  
            "response_mode": "blocking",  
            "auto_generate_name": true,  
            "inputs": [:]  
        ]
        
        print("DEBUG: Creating new conversation with name (via auto_generate_name): \(name)")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
             
            if let jsonStr = String(data: request.httpBody!, encoding: .utf8) {
                print("DEBUG: Create conversation request body: \(jsonStr)")
            }
        } catch {
            print("DEBUG: Failed to serialize conversation request body: \(error.localizedDescription)")
            logger.error("Failed to serialize request body: \(error.localizedDescription)")
            return Fail(error: APIError.encodingError(error)).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .handleEvents(
                receiveSubscription: { _ in print("DEBUG: Starting createConversation request") },
                receiveOutput: { output in 
                    print("DEBUG: Received create conversation response of \(output.data.count) bytes")
                    if let str = String(data: output.data, encoding: .utf8) {
                        print("DEBUG: Create conversation response: \(str)")
                    }
                },
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        print("DEBUG: createConversation request completed successfully")
                    case .failure(let error):
                        print("DEBUG: createConversation request failed with error: \(error)")
                    }
                },
                receiveCancel: { print("DEBUG: createConversation request was cancelled") }
            )
            .mapError { error -> APIError in
                print("DEBUG: createConversation error: \(error.localizedDescription)")
                return .networkError(error)
            }
            .map { $0.data }
            .eraseToAnyPublisher()
    }
}
