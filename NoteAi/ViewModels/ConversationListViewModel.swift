import Foundation
import Combine
import SwiftUI

class ConversationListViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isCreatingConversation = false
    @Published var newlyCreatedConversationId: String? = nil
    
    private let apiService: ChatAPIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: ChatAPIService = ChatAPIService()) {
        self.apiService = apiService
        
         
        loadConversations()
    }
    
    func loadConversations() {
        isLoading = true
        errorMessage = nil
        
        apiService.getConversations()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] (completion: Subscribers.Completion<APIError>) in
                guard let self = self else { return }
                self.isLoading = false
                
                if case .failure(let error) = completion {
                    self.errorMessage = "Failed to load conversations: \(error.localizedDescription)"
                    print("DEBUG: Error loading conversations: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] (data: Data) in
                guard let self = self else { return }
                
                do {
                    print("DEBUG: Received conversation list data of \(data.count) bytes")
                    
                     
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print("DEBUG: Parsed JSON object: \(json)")
                        
                        if let limit = json["limit"] as? Int {
                            print("DEBUG: Limit: \(limit)")
                        }
                        
                        if let hasMore = json["has_more"] as? Bool {
                            print("DEBUG: Has more: \(hasMore)")
                        }
                        
                        if let conversationsArray = json["data"] as? [[String: Any]] {
                            print("DEBUG: Found data array with \(conversationsArray.count) conversations")
                        }
                    }
                    
                     
                    let response = try JSONDecoder().decode(ConversationsResponse.self, from: data)
                    print("DEBUG: Successfully decoded \(response.data.count) conversations")
                    print("DEBUG: Response has limit: \(response.limit), hasMore: \(response.hasMore)")
                    
                     
                    self.conversations = response.data.sorted(by: { $0.updatedAt > $1.updatedAt })
                    print("DEBUG: Updated UI with \(self.conversations.count) conversations")
                } catch {
                    self.errorMessage = "Failed to parse conversations: \(error.localizedDescription)"
                    print("DEBUG: Error parsing conversations: \(error.localizedDescription)")
                }
            })
            .store(in: &cancellables)
    }
    
    func createNewConversation(name: String = "Chat \(Date().formatted(.dateTime.month().day().hour().minute()))") {
        isLoading = true
        isCreatingConversation = true
        errorMessage = nil
        newlyCreatedConversationId = nil
        
        print("DEBUG: Creating new conversation with name: \(name)")
        
        apiService.createConversation(name: name)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] (completion: Subscribers.Completion<APIError>) in
                guard let self = self else { return }
                self.isLoading = false
                self.isCreatingConversation = false
                
                if case .failure(let error) = completion {
                    self.errorMessage = "Failed to create conversation: \(error.localizedDescription)"
                    print("DEBUG: Error creating conversation: \(error.localizedDescription)")
                } else {
                     
                    self.loadConversations()
                }
            }, receiveValue: { [weak self] (data: Data) in
                guard let self = self else { return }
                
                 
                print("DEBUG: Chat message creation response: \(String(data: data, encoding: .utf8) ?? "none")")
                
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("DEBUG: Conversation creation response keys: \(json.keys)")
                    
                     
                    if let conversationId = json["conversation_id"] as? String {
                        print("DEBUG: Got new conversation ID: \(conversationId)")
                        self.newlyCreatedConversationId = conversationId
                    }
                }
            })
            .store(in: &cancellables)
    }
}
