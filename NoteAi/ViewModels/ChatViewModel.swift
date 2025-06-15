import Foundation
import Combine
import SwiftUI
import OSLog

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isStreamingResponse = false
    @Published var currentStreamedResponse: String = ""
    @Published var waitingTimeSeconds: Int = 0
    @Published var showLongWaitingAlert: Bool = false
    @Published var responseMode: String = "blocking"  
    
    private let apiService: ChatAPIService
    private let userId: String
    private var conversationId: String?
    private var cancellables = Set<AnyCancellable>()
    private var progressTimers = [String: Timer]()
    private var progressSeconds = [String: Int]()
    private var longWaitingTimer: Timer?
    var onNewConversationCreated: ((String) -> Void)?
    
    init(apiService: ChatAPIService = ChatAPIService(),
         userId: String = "user-123",
         conversationId: String?,
         onNewConversationCreated: ((String) -> Void)? = nil) {
        self.apiService = apiService
        self.userId = userId
        self.conversationId = conversationId
        self.onNewConversationCreated = onNewConversationCreated
        
         
        if let convId = conversationId, !convId.isEmpty {
            print("DEBUG: ChatViewModel initialized with existing conversationId: \(convId). Loading messages.")
            loadMessages()
        } else {
            print("DEBUG: ChatViewModel initialized without a conversationId. Will start a new conversation on first message.")
             
            self.messages = [] 
        }
    }
    
    func loadMessages() {
        guard let currentConvId = self.conversationId, !currentConvId.isEmpty else {
            print("DEBUG: loadMessages called but conversationId is nil or empty. Skipping fetch.")
            self.isLoading = false  
             
            return
        }
        isLoading = true
        
        apiService.getMessages(conversationId: currentConvId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                DispatchQueue.main.async { [weak self] in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("DEBUG: Error loading messages: \(error.localizedDescription)")
                        self?.errorMessage = "Failed to load messages: \(error.localizedDescription)"
                    }
                }
            }, receiveValue: { [weak self] data in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    do {
                         
                        let decoder = JSONDecoder()
                        let messageResponse = try decoder.decode(MessagesResponse.self, from: data)
                        print("DEBUG: Loaded \(messageResponse.data.count) messages from paginated response")
                        print("DEBUG: Response has limit: \(messageResponse.limit), hasMore: \(messageResponse.hasMore)")
                         
                        self.messages = messageResponse.data.sorted(by: { $0.createdAt < $1.createdAt })
                    } catch {
                        print("DEBUG: Failed to decode messages: \(error)")
                        self.errorMessage = "Failed to decode messages: \(error.localizedDescription)"
                    }
                }
            })
            .store(in: &cancellables)
    }
    
    func sendMessage(_ messageToSend: String) {
        guard !messageToSend.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
         
        let tempId = UUID().uuidString
        
         
        let currentTimestamp = Int(Date().timeIntervalSince1970)
        let tempMessage = Message(
            id: tempId,
            conversationId: self.conversationId ?? "",  
            query: messageToSend,
            answer: "",
            createdAt: currentTimestamp,
            parentMessageId: nil,
            status: "sending",
            agentThoughts: nil,
            error: nil,
            feedback: nil,
            inputs: nil,
            messageFiles: nil,
            _retrieverResources: nil
        )
        
         
        DispatchQueue.main.async {
            self.messages.append(tempMessage)
        }
        
         
        startWaitingTimer()
        
         
        apiService.sendChatMessage(
            query: messageToSend,
            userId: userId,
            conversationId: self.conversationId,  
            responseMode: responseMode
        )
        .sink(
            receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.stopWaitingTimer()
                    if case .failure(let error) = completion {
                        print("DEBUG: Error sending message: \(error.localizedDescription)")
                        self.errorMessage = "Failed to send message: \(error.localizedDescription)"
                         
                        if let index = self.messages.firstIndex(where: { $0.id == tempId }) {
                            self.messages[index].status = "error"
                            self.messages[index].error = error.localizedDescription
                        }
                    }
                }
            },
            receiveValue: { [weak self] data in
                guard let self = self else { return }
                if self.responseMode == "streaming" {
                     
                    if let responseString = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.processSSEEvents(responseString, messageToSend: messageToSend, tempId: tempId)
                        }
                    }
                } else {
                     
                    DispatchQueue.main.async {
                        let wasNewConversation = self.conversationId == nil || self.conversationId?.isEmpty == true
                        do {
                             
                            if let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                if wasNewConversation {
                                    if let newConvId = responseDict["conversation_id"] as? String, !newConvId.isEmpty {
                                        self.conversationId = newConvId
                                        print("DEBUG: New conversation created. Captured conversation_id: \(newConvId)")
                                        self.onNewConversationCreated?(newConvId)
                                    } else {
                                        print("ERROR: New conversation was expected, but 'conversation_id' missing or empty in response.")
                                         
                                    }
                                }
                                
                                if let answer = responseDict["answer"] as? String {
                                     
                                    self.createFinalResponse(messageToSend: messageToSend, tempId: tempId, answer: answer)
                                    self.stopWaitingTimer()
                                } else {
                                    print("DEBUG: Unexpected response format or missing answer. Full response: \(responseDict)")
                                    self.errorMessage = "Unexpected response format from server."
                                }
                            } else {
                                print("DEBUG: Failed to cast JSON object to [String: Any].")
                                self.errorMessage = "Failed to parse server response structure."
                            }
                        } catch {
                             
                            print("DEBUG: Error parsing response: \(error.localizedDescription)")
                            self.errorMessage = "Failed to parse response: \(error.localizedDescription)"
                        }
                    }
                }
            }
        )
        .store(in: &cancellables)
    }
    
    private func processSSEEvents(_ rawData: String, messageToSend: String, tempId: String) {
         
        print("DEBUG: Processing SSE event: \(rawData)")
        
         
        if rawData.contains("event: done") {
             
            createFinalResponse(messageToSend: messageToSend, tempId: tempId, answer: currentStreamedResponse)
            
             
            DispatchQueue.main.async {
                self.isStreamingResponse = false
                self.currentStreamedResponse = ""
            }
            return
        }
        
         
        if rawData.contains("event: message") {
             
            do {
                 
                var answer = ""
                
                 
                if let jsonStartIndex = rawData.range(of: "{")?.lowerBound,
                   let jsonEndIndex = rawData.range(of: "}", options: .backwards)?.upperBound {
                    
                    let jsonString = String(rawData[jsonStartIndex..<jsonEndIndex])
                    
                     
                    if let jsonData = jsonString.data(using: .utf8) {
                        if let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                             
                            if let jsonAnswer = json["answer"] as? String {
                                answer = jsonAnswer
                            }
                        }
                    }
                }
                
                 
                if !answer.isEmpty {
                    DispatchQueue.main.async {
                        self.isStreamingResponse = true
                        self.currentStreamedResponse = answer
                        
                         
                        self.updateMessageText(tempId: tempId, newAnswer: answer)
                    }
                } else {
                    print("DEBUG: Could not extract answer from SSE event")
                }
            } catch {
                print("DEBUG: Error processing SSE event: \(error.localizedDescription)")
            }
        }
    }
    
     
    private func updateMessageText(tempId: String, newAnswer: String) {
        DispatchQueue.main.async {
            if let index = self.messages.firstIndex(where: { $0.id == tempId }) {
                let oldMessage = self.messages[index]
                let updatedMessage = oldMessage.withUpdatedAnswer(newAnswer)
                self.messages[index] = updatedMessage
            }
        }
    }  
    
     
    private func createFinalResponse(messageToSend: String, tempId: String, answer: String) {
        if !answer.isEmpty {
             
            if let index = self.messages.firstIndex(where: { $0.id == tempId }) {
                let oldMessage = self.messages[index]
                 
                let finalMessage = Message(
                    id: tempId,
                    conversationId: self.conversationId ?? "",  
                    query: messageToSend,
                    answer: answer,
                    createdAt: oldMessage.createdAt,  
                    parentMessageId: nil,
                    status: "normal",   
                    agentThoughts: nil,
                    error: nil,
                    feedback: nil,
                    inputs: nil,
                    messageFiles: nil,
                    _retrieverResources: nil
                )
                DispatchQueue.main.async {
                    self.messages[index] = finalMessage
                }
            }
        }
    }  
    
     
    
    private func startWaitingTimer() {
         
        DispatchQueue.main.async { [weak self] in
            self?.waitingTimeSeconds = 0
            self?.showLongWaitingAlert = false
        }
         
        stopWaitingTimer()
         
        longWaitingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.waitingTimeSeconds += 1
                 
                if self.waitingTimeSeconds >= 180 && !self.showLongWaitingAlert {
                    self.showLongWaitingAlert = true
                }
            }
        }
    }
    
    private func stopWaitingTimer() {
        longWaitingTimer?.invalidate()
        longWaitingTimer = nil
        DispatchQueue.main.async { [weak self] in
            self?.showLongWaitingAlert = false
        }
    }
    
     
    deinit {
        print("ChatViewModel deinit")
        stopWaitingTimer()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}
