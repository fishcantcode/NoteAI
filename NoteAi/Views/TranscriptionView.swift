import SwiftUI
import AVKit

struct TranscriptionView: View {
    @StateObject private var viewModel = TranscriptionViewModel()
    @State private var transcriptionTitle = ""
    @State private var showCopiedToast = false
    @State private var isEditingText = false
    @State private var showSummary = false
    
    var body: some View {
        VStack {
             
            TextField("Enter title for your recording", text: $viewModel.documentTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
             
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                     
                    HStack {
                        if viewModel.isRecording {
                            Text(formattedTime(viewModel.recordingTime))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.red)
                                .frame(width: 80, alignment: .leading)
                        }
                        
                        Spacer()
                        
                        if viewModel.isRecording {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .opacity(viewModel.audioLevel > 0.1 ? 1 : 0.5)
                                .scaleEffect(viewModel.audioLevel > 0.1 ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.15), value: viewModel.audioLevel)
                            
                            Text("Recording...")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else if !viewModel.transcriptionText.isEmpty {
                            Text("Duration: \(formattedTime(viewModel.finalRecordingDuration))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                     
                    VStack(alignment: .leading) {
                        if viewModel.transcriptionText.isEmpty && !viewModel.isRecording {
                            Text("Tap the microphone button to start recording")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                 
                                if !viewModel.transcriptionText.isEmpty {
                                    Text(viewModel.transcriptionText)
                                        .padding(.bottom, 4)
                                }
                                
                                 
                                if viewModel.isRecording {
                                    if viewModel.isDetectingSpeech {
                                        Text("Waiting for speech...")
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Listening... Tap to pause")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(radius: 1)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            
             
            Spacer().frame(height: 20)
            
             
             
            Button(action: {
                if viewModel.isRecording {
                    viewModel.stopLiveTranscription()
                } else {
                    viewModel.startLiveTranscription()
                }
            }) {
                VStack {
                    Image(systemName: viewModel.isRecording ? "pause.circle.fill" : "mic.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(viewModel.isRecording ? .orange : .blue)
                    
                    if !viewModel.transcriptionText.isEmpty && !viewModel.isRecording {
                        Text("Tap to continue")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.bottom, 30)
            
             
            if !viewModel.transcriptionText.isEmpty {
                Button("Copy Transcription") {
                    UIPasteboard.general.string = viewModel.transcriptionText
                    showCopiedToast = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
            }
        }
        .navigationTitle("Audio Transcription")
        .navigationBarItems(trailing: Button(action: {
            viewModel.prepareForEditing()
            isEditingText = true
        }) {
            Image(systemName: "pencil")
        }
            .disabled(viewModel.isRecording || viewModel.transcriptionText.isEmpty))
        .onDisappear {
             
            viewModel.cleanup()
        }
         
         
        .sheet(isPresented: $isEditingText) {
            NavigationView {
                VStack {
                    TextEditor(text: $viewModel.editableText)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding()
                    
                    Button(action: {
                        viewModel.summarizeWithDify()
                        showSummary = true
                        isEditingText = false
                    }) {
                        HStack {
                            Image(systemName: "text.badge.star")
                            Text("Summarize with AI")
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.bottom)
                    .disabled(viewModel.editableText.isEmpty)
                }
                .navigationBarTitle("Edit Transcription", displayMode: .inline)
                .navigationBarItems(trailing: Button("Done") {
                    isEditingText = false
                })
            }
        }
         
        .sheet(isPresented: $showSummary) {
            NavigationView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Original Text:")
                        .font(.headline)
                    
                    ScrollView {
                        Text(viewModel.editableText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 200)
                    
                    Divider()
                    
                    Text("Summary:")
                        .font(.headline)
                    
                    if viewModel.isSummarizing {
                        VStack {
                            ProgressView("Generating summary...")
                            Text("This may take a moment...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding()
                    } else if !viewModel.summary.isEmpty {
                        ScrollView {
                            Text(viewModel.summary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(radius: 1)
                                .onAppear {
                                    print("Summary view appeared with content: \(viewModel.summary.prefix(50))...")
                                }
                        }
                    } else {
                        VStack {
                            Text("No summary available yet.")
                                .foregroundColor(.secondary)
                            if !viewModel.editableText.isEmpty {
                                Button(action: {
                                    viewModel.summarizeWithDify()
                                }) {
                                    Text("Generate Summary")
                                        .font(.subheadline)
                                        .padding(8)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding()
                    }
                    
                    Spacer()
                    
                    HStack {
                        Button(action: {
                            viewModel.saveSummaryToFile()
                        }) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                Text("Save Summary")
                            }
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(viewModel.summary.isEmpty)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.summarizeWithDify()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Regenerate")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(viewModel.editableText.isEmpty || viewModel.isSummarizing)
                    }
                    .padding()
                }
                .padding()
                .navigationBarTitle("AI Summary", displayMode: .inline)
                .navigationBarItems(trailing: Button("Done") {
                    showSummary = false
                })
            }
        }
        .overlay(Group {
            if showCopiedToast {
                VStack {
                    Text("Copied to clipboard")
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .shadow(radius: 2)
                        .padding()
                    Spacer()
                }
                .transition(.opacity)
                .animation(.easeInOut)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopiedToast = false
                    }
                }
            }
        })
        .alert(item: Binding<TranscriptionError?>(
            get: { viewModel.errorMessage.map { TranscriptionError(message: $0) } },
            set: { viewModel.errorMessage = $0?.message }
        )) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func formattedTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, milliseconds)
    }
    

    
     
    struct TranscriptionError: Identifiable {
        let id = UUID()
        let message: String
    }
    
     
}
