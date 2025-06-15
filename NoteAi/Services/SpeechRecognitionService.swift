import Foundation
import Speech
import AVFoundation

 
fileprivate struct LocalTranscriptionSegment {
    let text: String
    let timestamp: Double
    let isFinal: Bool
    
    func toTranscriptionSegment() -> TranscriptionSegment {
        return TranscriptionSegment(text: text, timestamp: timestamp, isFinal: isFinal)
    }
}

class SpeechRecognitionService {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    typealias TranscriptionCallback = (TranscriptionSegment) -> Void
    typealias ErrorCallback = (Error) -> Void
    
    func startLiveTranscription(callback: @escaping TranscriptionCallback, errorCallback: @escaping ErrorCallback) {
        print("START: Beginning live transcription process")
        
         
        stopLiveTranscription()
        print("START: Requesting speech recognition authorization")
         
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            
            switch status {
            case .authorized:
                print("START: Speech recognition authorization granted")
                 
                do {
                    try self.startRecording(callback: callback, errorCallback: errorCallback)
                } catch {
                    print("START: Transcription failed to start: \(error)")
                    DispatchQueue.main.async {
                        errorCallback(error)
                    }
                }
            case .denied:
                print("START: Speech recognition authorization denied")
                let error = NSError(domain: "SpeechRecognition", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition authorization was denied"])
                DispatchQueue.main.async {
                    errorCallback(error)
                }
            case .restricted:
                print("START: Speech recognition is restricted on this device")
                let error = NSError(domain: "SpeechRecognition", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech recognition is restricted on this device"])
                DispatchQueue.main.async {
                    errorCallback(error)
                }
            case .notDetermined:
                print("START: Speech recognition authorization not determined")
                let error = NSError(domain: "SpeechRecognition", code: 3, userInfo: [NSLocalizedDescriptionKey: "Speech recognition authorization not determined"])
                DispatchQueue.main.async {
                    errorCallback(error)
                }
            @unknown default:
                print("START: Unknown speech recognition authorization status")
                let error = NSError(domain: "SpeechRecognition", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unknown speech recognition authorization status"])
                DispatchQueue.main.async {
                    errorCallback(error)
                }
            }
        }
    }
    
    func stopLiveTranscription() {
        print("STOP: Stopping live transcription")
        
        if audioEngine.isRunning {
            print("STOP: Stopping audio engine")
            audioEngine.stop()
            do {
                print("STOP: Removing audio tap")
                audioEngine.inputNode.removeTap(onBus: 0)
            } catch {
                print("STOP: Error removing audio tap: \(error)")
                 
            }
        } else {
            print("STOP: Audio engine was not running")
        }
        
         
        if let recognitionRequest = self.recognitionRequest {
            print("STOP: Ending audio in recognition request")
            recognitionRequest.endAudio()
            self.recognitionRequest = nil
        }
        
         
        if let recognitionTask = self.recognitionTask {
            print("STOP: Cancelling recognition task")
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
         
        do {
            print("STOP: Deactivating audio session")
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("STOP: Audio session deactivated successfully")
        } catch {
            print("STOP: Error deactivating audio session: \(error)")
             
        }
        
        print("STOP: Live transcription stopped successfully")
    }
    
    private func startRecording(callback: @escaping TranscriptionCallback, errorCallback: @escaping ErrorCallback) throws {
         
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
         
        print("RECORDING: Creating speech recognition request")
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else { 
            let error = NSError(domain: "SpeechRecognition", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unable to create speech recognition request"])
            print("RECORDING: Failed to create recognition request")
            errorCallback(error)
            return 
        }
        
         
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            let error = NSError(domain: "SpeechRecognition", code: 6, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is not available"])
            print("RECORDING: Speech recognizer is not available")
            errorCallback(error)
            return
        }
        
         
        recognitionRequest.shouldReportPartialResults = true
        
         
        print("RECORDING: Starting speech recognition task")
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
             
            if let error = error {
                print("RECORDING: Recognition error: \(error)")
                DispatchQueue.main.async {
                    errorCallback(error)
                }
                return
            }
            
             
            guard let result = result else { 
                print("RECORDING: No result available from recognition task")
                return 
            }
            
             
            let localSegment = LocalTranscriptionSegment(
                text: result.bestTranscription.formattedString,
                timestamp: result.bestTranscription.segments.last?.timestamp ?? 0,
                isFinal: result.isFinal
            )
            
            let segment = localSegment.toTranscriptionSegment()
            
            DispatchQueue.main.async {
                callback(segment)
            }
            
             
            if result.isFinal {
                print("RECORDING: Recognition completed with final result")
            }
        }
        
         
        let inputNode = audioEngine.inputNode
        
         
        print("RECORDING: Removing any existing audio taps")
        if audioEngine.isRunning {
            inputNode.removeTap(onBus: 0)
        }
        
         
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("RECORDING: Setting up audio tap with format \(recordingFormat)")
        
         
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
             
            recognitionRequest.append(buffer)
        }
        
         
        print("RECORDING: Preparing audio engine")
        audioEngine.prepare()
        
        print("RECORDING: Starting audio engine")
        try audioEngine.start()
        print("RECORDING: Audio engine started successfully")
    }
}
