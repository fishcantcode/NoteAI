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
                            Text("Duration: " + String(format: "%d:%02d", Int((viewModel.isFinished ? viewModel.finalRecordingDuration : viewModel.recordingTime)) / 60, Int((viewModel.isFinished ? viewModel.finalRecordingDuration : viewModel.recordingTime)) % 60))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading) {
                        if viewModel.transcriptionText.isEmpty && !viewModel.isRecording && !viewModel.isFinished {
                            Text("Tap the microphone button to start recording")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            if !viewModel.transcriptionText.isEmpty {
                                Text(viewModel.transcriptionText)
                                    .padding(.bottom, 4)
                            }
                        }
                        
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            
            
            Spacer().frame(height: 20)
            
            
            
            if viewModel.isRecording {
                RecordingCardView(viewModel: viewModel, isEditingText: $isEditingText)
                    .padding(.bottom, 30)
            } else if !viewModel.isRecording && !viewModel.isFinished && !viewModel.transcriptionText.isEmpty {
                PausedCardView(viewModel: viewModel, isEditingText: $isEditingText)
                    .padding(.bottom, 30)
            } else if viewModel.isFinished && !viewModel.transcriptionText.isEmpty {
                FinishedStateActionsView(viewModel: viewModel, showCopiedToast: $showCopiedToast, isEditingText: $isEditingText)
                    .padding(.horizontal)
                    .padding(.bottom)
            } else {
                InitialMicButtonView(viewModel: viewModel)
                    .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background").ignoresSafeArea())
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
                .alert("Success", isPresented: $viewModel.showSaveSuccessAlert) {
                    Button("OK", role: .cancel) {
                        showSummary = false 
                    }
                } message: {
                    Text("Summary saved successfully.")
                }
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
                .animation(.easeInOut, value: showCopiedToast)
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
    private struct InitialMicButtonView: View {
        @ObservedObject var viewModel: TranscriptionViewModel

        var body: some View {
            Button(action: {
                viewModel.startLiveTranscription()
            }) {
                VStack {
                    Image(systemName: "mic.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                    
                    if !viewModel.transcriptionText.isEmpty {
                        Text("Tap to continue")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private struct FinishedStateActionsView: View {
        @ObservedObject var viewModel: TranscriptionViewModel
        @Binding var showCopiedToast: Bool
        @Binding var isEditingText: Bool

        var body: some View {
            HStack(spacing: 16) {
                Button(action: {
                    viewModel.prepareForEditing() 
                    isEditingText = true
                }) {
                    Label("Edit", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    UIPasteboard.general.string = viewModel.transcriptionText
                    showCopiedToast = true
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private struct PausedCardView: View {
        @ObservedObject var viewModel: TranscriptionViewModel
        @Binding var isEditingText: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Paused")
                        .font(.headline)
                   
                }
                
                Text(String(format: "%d:%02d", Int(viewModel.recordingTime) / 60, Int(viewModel.recordingTime) % 60))
                    .font(.title2.monospacedDigit())
                    .foregroundColor(.blue)
                
                HStack {
                    Button(action: {
                        viewModel.startLiveTranscription() 
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Continue")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                           
                    Button(action: {
                        viewModel.performFinishFusion()
                        isEditingText = true 
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Finish & Edit")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(10)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private struct RecordingCardView: View {
        @ObservedObject var viewModel: TranscriptionViewModel
        @Binding var isEditingText: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Recording")
                        .font(.headline)
                    
                    Spacer()
                }
                
                Text(String(format: "%d:%02d", Int(viewModel.recordingTime) / 60, Int(viewModel.recordingTime) % 60))
                    .font(.title2.monospacedDigit())
                    .foregroundColor(.blue)
                
                HStack {
                    Button(action: {
                        viewModel.stopLiveTranscription() 
                    }) {
                        HStack {
                            Image(systemName: "pause.fill")
                            Text("Pause")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .cornerRadius(10)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Button(action: {
                        viewModel.performFinishFusion()
                        isEditingText = true
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Finish & Edit")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(10)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }

    struct TranscriptionError: Identifiable {
        let id = UUID()
        let message: String
    }
}
