import Foundation
import Combine
import SwiftUI
import OSLog
import AVFoundation
import Speech

class ChatViewModel: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isStreamingResponse = false
    @Published var currentStreamedResponse: String = ""
    @Published var waitingTimeSeconds: Int = 0
    @Published var showLongWaitingAlert: Bool = false
    @Published var responseMode: String = "blocking"
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var isDetectingSpeech = false
    @Published var recordingTime: TimeInterval = 0
    @Published var finalRecordingDuration: TimeInterval = 0
    @Published var currentTranscription = ""
    @Published var isFinished = false
    
    private let apiService: ChatAPIService
    private let userId: String
    private var conversationId: String?
    private var sourceDocumentId: String? // Track the originating document
    private var cancellables = Set<AnyCancellable>()
    private var progressTimers = [String: Timer]()
    private var progressSeconds = [String: Int]()
    private var longWaitingTimer: Timer?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recordingTimer: Timer?
    var onNewConversationCreated: ((String) -> Void)?
    init(apiService: ChatAPIService = ChatAPIService(),
         userId: String = "user-123",
         conversationId: String?,
         sourceDocumentId: String? = nil,
         onNewConversationCreated: ((String) -> Void)? = nil) {
        self.apiService = apiService
        self.userId = userId
        self.conversationId = conversationId
        self.sourceDocumentId = sourceDocumentId
        self.onNewConversationCreated = onNewConversationCreated
        
        super.init()
        
        self.speechRecognizer?.delegate = self
        requestMicrophonePermission()
        
        if let convId = conversationId, !convId.isEmpty {
            print("DEBUG: ChatViewModel initialized with existing conversationId: \(convId). Loading messages.")
            loadMessages()
        } else {
            print("DEBUG: ChatViewModel initialized without a conversationId. Will start a new conversation on first message.")
            self.messages = []
        }
    }
    
    private func requestMicrophonePermission() {
        #if canImport(AVAudioApplication)
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if !granted {
                    self?.errorMessage = "Microphone permission is required for recording."
                }
            }
        }
        #else
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if !granted {
                    self?.errorMessage = "Microphone permission is required for recording."
                }
            }
        }
        #endif
    }
    
    func startRecording() {
        guard !isRecording else { return }

        if self.isFinished {
            self.currentTranscription = ""
            self.recordingTime = 0
            self.finalRecordingDuration = 0
        }
        self.isFinished = false

        currentTranscription = ""
        isProcessing = true
        isDetectingSpeech = true
        isRecording = true
        recordingTime = 0
        finalRecordingDuration = 0

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to set up audio session: \(error.localizedDescription)"
            stopRecording()
            return
        }

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            errorMessage = "Failed to create audio engine"
            stopRecording()
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Failed to create recognition request"
            stopRecording()
            return
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        

        startRecordingTimer()

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                self.currentTranscription = result.bestTranscription.formattedString
                isFinal = result.isFinal
                self.isDetectingSpeech = false
            }
            
            if error != nil || isFinal {
                audioEngine.stop()
                audioEngine.inputNode.removeTap(onBus: 0)
                recognitionRequest.endAudio()
                recognitionTask?.finish() 
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                if isFinal {
                    self.finalizeRecording()
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            stopRecording()
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        
        if let inputNode = audioEngine?.inputNode {
            inputNode.removeTap(onBus: 0)
        }
        
        stopRecordingTimer()

        isRecording = false
        isProcessing = false
        isDetectingSpeech = false
        finalRecordingDuration = recordingTime
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    private func finalizeRecording() {}

    func finishRecording() {
        self.stopRecording()

        if !currentTranscription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sendMessage(self.currentTranscription)
        }
        self.currentTranscription = ""
        self.isFinished = true
    }
    
    private func startRecordingTimer() {
        stopRecordingTimer()
        let startTime = recordingTime
        let startDate = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let elapsed = Date().timeIntervalSince(startDate)
            self.recordingTime = startTime + elapsed
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    

    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            errorMessage = "Speech recognition is not available"
            stopRecording()
        }
    }
    
    deinit {
        stopRecording()
        stopRecordingTimer()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
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
            var answer = ""
            if let jsonStartIndex = rawData.range(of: "{")?.lowerBound,
               let jsonEndIndex = rawData.range(of: "}", options: .backwards)?.upperBound {
                let jsonString = String(rawData[jsonStartIndex..<jsonEndIndex])
                if let jsonData = jsonString.data(using: .utf8) {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let jsonAnswer = json["answer"] as? String {
                            answer = jsonAnswer
                        }
                    } catch {
                        print("DEBUG: Failed to deserialize JSON from SSE event: \(error.localizedDescription)")
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
    
}
