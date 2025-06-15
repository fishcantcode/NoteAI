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
                        Circle()
                            .fill(viewModel.isRecording ? Color.red : Color.gray)
                            .frame(width: 12, height: 12)
                        
                        Text(viewModel.isRecording ? "Recording..." : "Not recording")
                            .font(.caption)
                            .foregroundColor(viewModel.isRecording ? .red : .gray)
                        
                        Spacer()
                        
                        if !viewModel.isRecording && !viewModel.transcriptionText.isEmpty {
                            Text("Duration: \(formattedTime(viewModel.segments.last?.timestamp ?? 0))")
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
                                    HStack(spacing: 0) {
                                        Text(viewModel.currentStreamingText.isEmpty ? "Listening..." : viewModel.currentStreamingText)
                                            .foregroundColor(viewModel.currentStreamingText.isEmpty ? .secondary : .primary)
                                        
                                         
                                        if !viewModel.currentStreamingText.isEmpty {
                                            Text("_")
                                                .opacity(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1.0) > 0.5 ? 1 : 0)
                                                .animation(.easeInOut(duration: 0.5), value: Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1.0) > 0.5)
                                        }
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
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(viewModel.isRecording ? .red : .blue)
                    
                    Text(viewModel.isRecording ? "Stop Recording" : "Start Recording")
                        .font(.callout)
                        .padding(.top, 8)
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
                        ProgressView("Generating summary...")
                            .padding()
                    } else if !viewModel.summary.isEmpty {
                        ScrollView {
                            Text(viewModel.summary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(radius: 1)
                        }
                    } else {
                        Text("No summary available yet.")
                            .foregroundColor(.secondary)
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
    
    private func formattedTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
     
    struct TranscriptionError: Identifiable {
        let id = UUID()
        let message: String
    }
    
     
}
