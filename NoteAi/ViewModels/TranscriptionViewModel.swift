import Foundation
import Combine
import SwiftUI
import AVFoundation
import Speech

class TranscriptionViewModel: ObservableObject {
     
    @Published var isRecording = false
    @Published var isFinished = false
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
    @Published var showSaveSuccessAlert: Bool = false
    
    @Published var documentId: String = UUID().uuidString
    
    private let speechRecognitionService = SpeechRecognitionService()
    private var audioLevelTimer: Timer?
    private var audioLevelObserver: NSObjectProtocol?
    private var recordingTimer: Timer?
    private let documentManager = DocumentManager.shared
    
    init() {
        checkPermissions()
        setupAudioSession()
    }
    
     
    
    private func checkPermissions() {
        checkMicrophonePermission()
        checkSpeechRecognitionPermission()
    }
    
    private func checkMicrophonePermission() {
        #if canImport(AVAudioApplication)
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            self.microphonePermissionGranted = true
        case .denied:
            self.microphonePermissionGranted = false
            self.errorMessage = "Microphone access is required for recording. Please grant access in Settings."
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.microphonePermissionGranted = granted
                    if !granted {
                        self?.errorMessage = "Microphone access is required for recording. Please grant access in Settings."
                    }
                }
            }
        @unknown default:
            self.microphonePermissionGranted = false
        }
        #else
        let audioSession = AVAudioSession.sharedInstance()
        switch audioSession.recordPermission {
        case .granted:
            self.microphonePermissionGranted = true
        case .denied:
            self.microphonePermissionGranted = false
            self.errorMessage = "Microphone access is required for recording. Please grant access in Settings."
        case .undetermined:
            audioSession.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.microphonePermissionGranted = granted
                    if !granted {
                        self?.errorMessage = "Microphone access is required for recording. Please grant access in Settings."
                    }
                }
            }
        @unknown default:
            self.microphonePermissionGranted = false
        }
        #endif
    }
    
    private func checkSpeechRecognitionPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
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
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to setup audio recording: \(error.localizedDescription)"
        }
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
    
    func startLiveTranscription() {
        errorMessage = nil
        
        if transcriptionText.isEmpty {
            transcriptionText = "Starting transcription..."
        } else {
            let lastChar = transcriptionText.last
            if lastChar != " " && lastChar != "." && lastChar != "!" && lastChar != "?" {
                transcriptionText += " "
            }
        }
        currentStreamingText = ""
        isProcessing = true
        isDetectingSpeech = true
        isRecording = true
        startRecordingTimer()
        if !microphonePermissionGranted {
            errorMessage = "Microphone permission is required. Please grant access in Settings."
            isProcessing = false; isRecording = false; isDetectingSpeech = false; stopRecordingTimer()
            return
        }
        if !speechRecognitionAuthorized {
            errorMessage = "Speech recognition permission is required."
            isProcessing = false; isRecording = false; isDetectingSpeech = false; stopRecordingTimer()
            return
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            if !audioSession.isInputAvailable {
                errorMessage = "No microphone available. Please check your device."
                isProcessing = false; isRecording = false; isDetectingSpeech = false; stopRecordingTimer()
                return
            }
            
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio setup failed: \(error.localizedDescription)"
            isProcessing = false; isRecording = false; isDetectingSpeech = false; stopRecordingTimer()
            return
        }
        
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
                    }
                    self.currentStreamingText = ""
                } else {
                    self.currentStreamingText = segmentData.text
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
                return
            }
            
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
    
    func finishRecording() {
        stopLiveTranscription()
        isFinished = true
    }
    
    func stopLiveTranscription() {
        guard isRecording else { return }
        
        speechRecognitionService.stopLiveTranscription()
        finalRecordingDuration = recordingTime
        
        stopRecordingTimer()
        stopAudioLevelMonitoring()
        
        if !currentStreamingText.isEmpty {
            let trimmedStreamingText = currentStreamingText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedStreamingText.isEmpty {
                let lastStreamingSegment = TranscriptionSegment(text: trimmedStreamingText, timestamp: recordingTime, isFinal: true)
                self.segments.append(lastStreamingSegment)
                let committedText = self.segments.map { $0.text }.joined(separator: " ")
                self.transcriptionText = committedText
            }
            currentStreamingText = ""
        }
        
        isRecording = false
        isDetectingSpeech = false
        isProcessing = false
    }
    
    private func stopRecording() {
        stopLiveTranscription()
    }
    
     
    
    private func startAudioLevelMonitoring() {
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
        summary = ""
        segments = []
        recordingTime = 0
        finalRecordingDuration = 0
        isFinished = false
        errorMessage = nil
        documentId = UUID().uuidString  
    }
    func getCurrentTranscriptionText() -> String {
        return transcriptionText
    }
    func prepareForEditing() {
        if editableText.isEmpty && !transcriptionText.isEmpty {
            editableText = transcriptionText
        }
    }

    func performFinishFusion() {
        if isRecording {
            stopLiveTranscription()
        }
        isFinished = true
        prepareForEditing()
    }
    
     
    func summarizeWithDify() {
        guard !editableText.isEmpty else {
            errorMessage = "No text to summarize. Please record or enter some text first."
            return
        }

        let difyService = DifyAPIService(
            apiKey: ConfigManager.shared.difyChatAPIKey,
            appID: ConfigManager.shared.difyKnowledgeID
        )

        isSummarizing = true
        errorMessage = nil 

        difyService.sendMessageForSummary(text: editableText) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSummarizing = false

                switch result {
                case .success(let summary):
                    self.summary = summary
                case .failure(let error):
                    self.errorMessage = "Summarization error: \(error.localizedDescription)"
                }
            }
        }
    }
    
     
    func saveSummaryToFile() -> Bool {
        guard !summary.isEmpty else {
            errorMessage = "No summary available to save."
            return false
        }

        var cleanedSummary = summary
        let regexPattern = "<think>.*?</think>"
        do {
            let regex = try NSRegularExpression(pattern: regexPattern, options: .dotMatchesLineSeparators)  
            let range = NSRange(cleanedSummary.startIndex..., in: cleanedSummary)
            cleanedSummary = regex.stringByReplacingMatches(in: cleanedSummary, options: [], range: range, withTemplate: "")
            cleanedSummary = cleanedSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("[VIEWMODEL] Error creating regex for <think> tag removal: \(error.localizedDescription)")
        }

         
        let summaryWithId = """
        DOCUMENT_ID: \(documentId)
        CREATED: \(Date().formatted())
        TITLE: \(documentTitle.isEmpty ? "Untitled Transcription" : documentTitle)
        
        ---
        
        \(cleanedSummary)
        """

        let fileName = "\(documentTitle.isEmpty ? "Untitled Summary" : documentTitle).txt"

        do {
            try documentManager.saveTextToFile(content: summaryWithId, fileName: fileName, documentId: documentId)
            self.showSaveSuccessAlert = true  
            return true  
        } catch {
            errorMessage = "Failed to save summary: \(error.localizedDescription)"
            return false  
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
        stopAudioLevelMonitoring()
        
        if isRecording {
            speechRecognitionService.stopLiveTranscription()
        }
    }
}
