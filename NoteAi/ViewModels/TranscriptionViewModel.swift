import Foundation
import Combine
import SwiftUI
import AVFoundation
import Speech

class TranscriptionViewModel: ObservableObject {
     
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0.0
    @Published var finalRecordingDuration: TimeInterval = 0.0
    @Published var isDetectingSpeech = false
    @Published var transcriptionText = ""
    @Published var currentStreamingText = ""  
    @Published var editableText = ""  
    @Published var segments: [TranscriptionSegment] = []
    @Published var errorMessage: String?
    @Published var microphonePermissionGranted = false
    @Published var speechRecognitionAuthorized = false
    @Published var audioLevel: Float = 0
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var documentTitle: String = "Untitled Transcription"  
    
     
    @Published var isSummarizing = false
    @Published var summary = ""
    
     
    private let speechRecognitionService = SpeechRecognitionService()
    private var audioLevelTimer: Timer?
    private var audioLevelObserver: NSObjectProtocol?
    private var recordingTimer: Timer?
    private let documentManager = DocumentManager.shared  
    
    init() {
        print("[VIEWMODEL] Initializing TranscriptionViewModel")
        checkPermissions()
        setupAudioSession()
    }
    
     
    
    private func checkPermissions() {
        print("[VIEWMODEL] Checking required permissions")
        checkMicrophonePermission()
        checkSpeechRecognitionPermission()
    }
    
    private func checkMicrophonePermission() {
        print("[VIEWMODEL] Checking microphone permission")
        let audioSession = AVAudioSession.sharedInstance()
        
        switch audioSession.recordPermission {
        case .granted:
            print("[VIEWMODEL] Microphone permission already granted")
            self.microphonePermissionGranted = true
        case .denied:
            print("[VIEWMODEL] Microphone permission denied")
            self.microphonePermissionGranted = false
            self.errorMessage = "Microphone access is required for recording. Please grant access in Settings."
        case .undetermined:
            print("[VIEWMODEL] Requesting microphone permission")
            audioSession.requestRecordPermission { [weak self] granted in
                print("[VIEWMODEL] Microphone permission response: \(granted)")
                DispatchQueue.main.async {
                    self?.microphonePermissionGranted = granted
                    if !granted {
                        self?.errorMessage = "Microphone access is required for recording. Please grant access in Settings."
                    }
                }
            }
        @unknown default:
            print("[VIEWMODEL] Unknown microphone permission status")
            self.microphonePermissionGranted = false
        }
    }
    
    private func checkSpeechRecognitionPermission() {
        print("[VIEWMODEL] Checking speech recognition permission")
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            print("[VIEWMODEL] Speech recognition permission status: \(status.rawValue)")
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.speechRecognitionAuthorized = true
                case .denied, .restricted, .notDetermined:
                    self?.speechRecognitionAuthorized = false
                    self?.errorMessage = "Speech recognition permission is required. Please grant access in Settings."
                @unknown default:
                    self?.speechRecognitionAuthorized = false
                }
            }
        }
    }
    
     
    
    private func setupAudioSession() {
        print("[VIEWMODEL] Setting up audio session")
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("[VIEWMODEL] Audio session setup successful")
            
            print("[VIEWMODEL] Current route: \(audioSession.currentRoute)")
            print("[VIEWMODEL] Input available: \(audioSession.isInputAvailable)")
            if let inputs = audioSession.availableInputs {
                print("[VIEWMODEL] Available inputs: \(inputs)")
            }
        } catch {
            print("[VIEWMODEL] Failed to setup audio session: \(error)")
            errorMessage = "Failed to setup audio recording: \(error.localizedDescription)"
        }
    }
    
     
    
    private func startRecordingTimer() {
        recordingTime = 0.0
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingTime += 0.1
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    func startLiveTranscription() {
        print("[VIEWMODEL] startLiveTranscription called")
        
        errorMessage = nil
        segments.removeAll() 
        transcriptionText = "Starting transcription..."
        currentStreamingText = "" 
        isProcessing = true
        isDetectingSpeech = true
        isRecording = true
        startRecordingTimer()
        
        if !microphonePermissionGranted {
            print("[VIEWMODEL] ERROR: Microphone permission not granted")
            errorMessage = "Microphone permission is required. Please grant access in Settings."
            isProcessing = false; isRecording = false; isDetectingSpeech = false; stopRecordingTimer()
            return
        }
        
        if !speechRecognitionAuthorized {
            print("[VIEWMODEL] ERROR: Speech recognition not authorized")
            errorMessage = "Speech recognition permission is required."
            isProcessing = false; isRecording = false; isDetectingSpeech = false; stopRecordingTimer()
            return
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            if !audioSession.isInputAvailable {
                print("[VIEWMODEL] ERROR: No audio input available")
                errorMessage = "No microphone available. Please check your device."
                isProcessing = false; isRecording = false; isDetectingSpeech = false; stopRecordingTimer()
                return
            }
            
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("[VIEWMODEL] Audio session reactivated successfully")
        } catch {
            print("[VIEWMODEL] ERROR: Failed to setup audio session: \(error)")
            errorMessage = "Audio setup failed: \(error.localizedDescription)"
            isProcessing = false; isRecording = false; isDetectingSpeech = false; stopRecordingTimer()
            return
        }
        
        print("[VIEWMODEL] Starting live transcription with service")
        
        let enhancedCallback: (TranscriptionSegment) -> Void = { [weak self] segmentData in
            guard let self = self, self.isRecording else { return }
            
            DispatchQueue.main.async {
                if self.isDetectingSpeech && !segmentData.text.isEmpty {
                    self.isDetectingSpeech = false
                    self.transcriptionText = "" 
                }

                if segmentData.isFinal {
                    if !segmentData.text.isEmpty {
                        let finalSegment = TranscriptionSegment(text: segmentData.text, timestamp: segmentData.timestamp, isFinal: true)
                        self.segments.append(finalSegment)
                        print("[VIEWMODEL] Final segment added: '\(finalSegment.text)'")
                    }
                    self.currentStreamingText = ""
                } else {
                    self.currentStreamingText = segmentData.text
                    print("[VIEWMODEL] Interim result: '\(segmentData.text.prefix(30))...'")
                }

                let committedText = self.segments.map { $0.text }.joined(separator: " ")
                if self.currentStreamingText.isEmpty {
                    self.transcriptionText = committedText
                } else {
                    self.transcriptionText = committedText.isEmpty ? self.currentStreamingText : committedText + " " + self.currentStreamingText
                }
            }
        }
        
        let enhancedErrorCallback: (Error) -> Void = { [weak self] error in
            guard let self = self else { return }
            
            let errorDescription = error.localizedDescription.lowercased()
            let isCancellationError = errorDescription.contains("cancel") || 
                                     (error as NSError).domain == "kLSRErrorDomain" && (error as NSError).code == 301
            
            if isCancellationError {
                print("[VIEWMODEL] Normal recording stop detected: \(error)")
                return
            }
            
            print("[VIEWMODEL] ERROR in speech recognition: \(error)")
            
            DispatchQueue.main.async {
                self.errorMessage = "Recording error: \(error.localizedDescription)"
                self.isRecording = false
                self.isDetectingSpeech = false
                self.isProcessing = false
                self.stopRecordingTimer()
                self.stopAudioLevelMonitoring()
            }
        }
        
        speechRecognitionService.startLiveTranscription(
            callback: enhancedCallback,
            errorCallback: enhancedErrorCallback
        )
        
        startAudioLevelMonitoring()
    }
    
    func stopLiveTranscription() {
        print("[VIEWMODEL] stopLiveTranscription called")
        speechRecognitionService.stopLiveTranscription()
        
        self.finalRecordingDuration = self.recordingTime
        stopRecordingTimer()
        isRecording = false
        isDetectingSpeech = false
        isProcessing = false
        stopAudioLevelMonitoring()
        
        if !currentStreamingText.isEmpty {
            let trimmedStreamingText = currentStreamingText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedStreamingText.isEmpty {
                let lastStreamingSegment = TranscriptionSegment(text: trimmedStreamingText, timestamp: recordingTime, isFinal: true)
                self.segments.append(lastStreamingSegment)
                let committedText = self.segments.map { $0.text }.joined(separator: " ")
                self.transcriptionText = committedText
                print("[VIEWMODEL] Finalized streaming text on stop: '\(trimmedStreamingText)'")
            }
            currentStreamingText = ""
        }
        print("[VIEWMODEL] Transcription completed. Final text: \(transcriptionText)")
    }
    
    private func stopRecording() {
        print("[VIEWMODEL] stopRecording() is now largely handled by stopLiveTranscription(). Ensure all state is reset there.")
    }
    
     
    
    private func startAudioLevelMonitoring() {
        print("[VIEWMODEL] Starting audio level monitoring")
        stopAudioLevelMonitoring()  
        
         
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.isRecording {
                 
                 
                let randomBase = Float.random(in: 0.1...0.7)
                let variation = Float.random(in: -0.2...0.2) 
                self.audioLevel = max(0, min(1.0, randomBase + variation))
            } else {
                self.audioLevel = 0
            }
        }
        
         
        setupRealAudioLevelMonitoring()
    }
    
    private func setupRealAudioLevelMonitoring() {
         
         
    }
    
    private func stopAudioLevelMonitoring() {
        print("[VIEWMODEL] Stopping audio level monitoring")
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        audioLevel = 0
        
         
        if let observer = audioLevelObserver {
            NotificationCenter.default.removeObserver(observer)
            audioLevelObserver = nil
        }
    }
    
     
    
     
    func clearTranscription() {
        transcriptionText = ""
        currentStreamingText = ""
        editableText = ""
        summary = ""
        segments = []
        errorMessage = nil
    }
    
     
    func getCurrentTranscriptionText() -> String {
        return transcriptionText
    }
    
     
    func prepareForEditing() {
         
        if editableText.isEmpty && !transcriptionText.isEmpty {
            editableText = transcriptionText
        }
    }
    
     
    
     
    func summarizeWithDify() {
        guard !editableText.isEmpty else {
            errorMessage = "No text to summarize. Please record or enter some text first."
            return
        }

        print("[VIEWMODEL] Using Dify Chat API Key: \(ConfigManager.shared.difyChatAPIKey)")
        print("[VIEWMODEL] Using Dify Knowledge ID: \(ConfigManager.shared.difyKnowledgeID)")

        let difyService = DifyAPIService(
            apiKey: ConfigManager.shared.difyChatAPIKey,
            appID: ConfigManager.shared.difyKnowledgeID
        )

        isSummarizing = true
        errorMessage = nil 

        print("[VIEWMODEL] Sending text for summarization...")

        difyService.sendMessageForSummary(text: editableText) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSummarizing = false

                switch result {
                case .success(let summary):
                    print("[VIEWMODEL] Received summary from Dify")
                    self.summary = summary
                    print("[VIEWMODEL] Summary set: \(summary.prefix(50))...")
                case .failure(let error):
                    print("[VIEWMODEL] Error getting summary: \(error.localizedDescription)")
                    self.errorMessage = "Summarization error: \(error.localizedDescription)"
                }
            }
        }
    }
    
     
    
    func saveSummaryToFile() {
        guard !summary.isEmpty else {
            errorMessage = "No summary available to save."
            print("[VIEWMODEL] Attempted to save empty summary.")
            return
        }

         
        var cleanedSummary = summary
        let regexPattern = "<think>.*?</think>"
        do {
            let regex = try NSRegularExpression(pattern: regexPattern, options: .dotMatchesLineSeparators)  
            let range = NSRange(cleanedSummary.startIndex..., in: cleanedSummary)
            cleanedSummary = regex.stringByReplacingMatches(in: cleanedSummary, options: [], range: range, withTemplate: "")
             
            cleanedSummary = cleanedSummary.trimmingCharacters(in: .whitespacesAndNewlines)
            print("[VIEWMODEL] Cleaned summary (after removing <think> tags): \(cleanedSummary.prefix(100))...")
        } catch {
            print("[VIEWMODEL] Error creating regex for <think> tag removal: \(error.localizedDescription)")
             
        }

        let fileName = "\(documentTitle.isEmpty ? "Untitled Summary" : documentTitle).txt"
        print("[VIEWMODEL] Attempting to save summary to file: \(fileName)")

        do {
             
            try documentManager.saveTextToFile(content: cleanedSummary, fileName: fileName)
            print("[VIEWMODEL] Successfully saved summary to \(fileName)")
             
             
             
        } catch {
            print("[VIEWMODEL] Error saving summary: \(error.localizedDescription)")
            errorMessage = "Failed to save summary: \(error.localizedDescription)"
        }
    }

     
    
     
    func cleanup() {
        if isRecording {
            stopLiveTranscription()
        }
        
         
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[VIEWMODEL] Error deactivating audio session during cleanup: \(error)")
        }
    }
    
    deinit {
        print("[VIEWMODEL] TranscriptionViewModel deinit called")
        stopAudioLevelMonitoring()
        
        if isRecording {
            speechRecognitionService.stopLiveTranscription()
        }
    }
}
