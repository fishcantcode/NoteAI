import SwiftUI
import UniformTypeIdentifiers  

struct FolderDetailView: View {
    @StateObject var viewModel: FolderDetailViewModel
     
     
     
    
    @State private var showingDocumentPicker = false  
    @State private var showingNewTextDocumentSheet = false
    @State private var newDocumentName: String = ""
    @State private var newDocumentContent: String = ""
    @State private var triggerFileImporter: Bool = false  
    
     
    @State private var selectedLocalSummary: Document?
    @State private var localSummaryContent: String = ""
    @State private var showingLocalSummarySheet: Bool = false
    
     
    init(dataset: KnowledgeDataset, apiManager: APIManager) {
        _viewModel = StateObject(wrappedValue: FolderDetailViewModel(dataset: dataset, apiManager: apiManager))
         
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 20)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(viewModel.dataset.name)  
                    .font(.largeTitle.bold())
                    .padding(.top)
                
                Text(viewModel.dataset.description ?? "No description available.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom)
                
                 
                HStack(spacing: 20) {
                    ActionButton(title: "Add File", systemImage: "doc.badge.plus", color: .blue) {
                        showingDocumentPicker = true
                    }
                    NavigationLink(destination: TranscriptionView()) {
                        HStack {
                            Image(systemName: "waveform.and.mic")
                            Text("Record & Summarize")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(radius: 3)
                    }
                }
                .padding(.bottom)
                
                 
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                 
                if viewModel.isLoading && viewModel.documents.isEmpty {  
                    ProgressView("Loading Documents...")
                        .padding()
                } else if viewModel.documents.isEmpty && viewModel.errorMessage == nil {
                    Text("No API documents found in this knowledge base.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    Section(header: Text("Knowledge Base Documents").font(.title2).padding(.top)) {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(viewModel.documents) { document in
                                DocumentCardView(document: document)  
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            viewModel.deleteDocument(document: document)
                                        } label: {
                                            Label("Delete Document", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                
                 
                localSummariesSection  
                
            }
            .padding()
        }
        .navigationTitle(viewModel.dataset.name)  
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Refresh") {
                    viewModel.loadDocuments()
                }
            }
        }
        .onAppear {
            viewModel.loadDocuments()
            viewModel.loadSummaryFiles()  
        }
        .sheet(isPresented: $showingLocalSummarySheet) {  
            VStack(alignment: .leading) {
                HStack {
                    Text(selectedLocalSummary?.name ?? "Summary")
                        .font(.title2.bold())
                    Spacer()
                    Button {
                        showingLocalSummarySheet = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding([.top, .horizontal])
                
                Divider()
                
                ScrollView {
                    Text(localSummaryContent)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)  
                }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
             
            VStack {
                Text("Upload Document").font(.headline).padding()
                
                if viewModel.isUploadingFile {
                    ProgressView("Uploading file...")
                        .padding()
                } else {
                    Button("Select File") {
                        triggerFileImporter = true
                    }
                    .padding()
                    .fileImporter(
                        isPresented: $triggerFileImporter,
                        allowedContentTypes: [.pdf, .plainText, .item, .utf8PlainText, .text, UTType.data],  
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let urls):
                            guard let selectedFileURL = urls.first else {
                                viewModel.uploadErrorMessage = "No file selected or URL could not be accessed."
                                return
                            }
                             
                             
                             
                            print("File selected: \(selectedFileURL)")
                            viewModel.uploadFile(fileURL: selectedFileURL)
                        case .failure(let error):
                            viewModel.uploadErrorMessage = "Failed to select file: \(error.localizedDescription)"
                            print("Error selecting file: \(error.localizedDescription)")
                        }
                    }
                }
                
                if let uploadError = viewModel.uploadErrorMessage {
                    Text(uploadError)
                        .foregroundColor(.red)
                        .padding()
                }
                
                 
                Spacer()
                
                Button("Done") {  
                    showingDocumentPicker = false
                    viewModel.uploadErrorMessage = nil  
                }.padding()
            }
            .frame(minWidth: 300, idealHeight: 250)
            .onDisappear {
                 
                 
                viewModel.uploadErrorMessage = nil
            }
        }
        .sheet(isPresented: $showingNewTextDocumentSheet) {
            VStack {
                Text("Create Text Document").font(.headline).padding()
                TextField("Document Name", text: $newDocumentName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                TextEditor(text: $newDocumentContent)
                    .frame(height: 200)
                    .border(Color.gray.opacity(0.5), width: 1)
                    .padding(.horizontal)
                HStack {
                    Button("Cancel") {
                        showingNewTextDocumentSheet = false
                    }.padding()
                    Spacer()
                    Button("Create") {
                        if !newDocumentName.isEmpty {
                            viewModel.createDocument(name: newDocumentName, content: newDocumentContent)
                            showingNewTextDocumentSheet = false
                        }
                    }.padding()
                }
            }
            .frame(minWidth: 400, minHeight: 400)
        }
    }
    
     
    @ViewBuilder
    private var localSummariesSection: some View {
        if !viewModel.summaryFiles.isEmpty {
            Section(header: Text("Saved Summaries").font(.title2).padding(.top)) {
                ForEach(Array(viewModel.summaryFiles)) { (summaryDocument: Document) in  
                    SummaryRowView(summaryDocument: summaryDocument, viewModel: viewModel) {
                         
                        self.selectedLocalSummary = summaryDocument
                        if let content = self.viewModel.getSummaryContent(for: summaryDocument) {
                            self.localSummaryContent = content
                        } else {
                            self.localSummaryContent = "Could not load summary content for \(summaryDocument.name)."
                        }
                        self.showingLocalSummarySheet = true
                    }
                    .contextMenu {  
                        Button(role: .destructive) {
                            viewModel.deleteLocalSummary(summaryDocument: summaryDocument)  
                        } label: {
                            Label("Delete Summary", systemImage: "trash")
                        }
                    }
                }
            }
        } else {
            Section(header: Text("Saved Summaries").font(.title2).padding(.top)) {
                Text("No saved summaries found.")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
        
     
    private func chatView(for summaryDocument: Document) -> some View {
        ChatView(
            conversationId: summaryDocument.difyConversationId,
            onNewConversationCreated: { newDifyConversationId in
                viewModel.saveDifyConversationId(for: summaryDocument, difyId: newDifyConversationId)
            }
        )
    }
    
     
    struct DocumentCardView: View {
        let document: APIDocument
        
        var body: some View {
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "doc.text.fill")  
                        .foregroundColor(.orange)
                    Text(document.name)
                        .font(.headline)
                        .lineLimit(2)
                }
                Spacer()
                Text("Status: \(document.indexing_status ?? "N/A")")
                    .font(.caption)
                    .foregroundColor(.gray)
                if let createdAt = document.created_at {
                    Text("Created: \(Date(timeIntervalSince1970: createdAt), style: .date)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 100)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(10)
            .shadow(radius: 1)
        }
    }
    
     
    struct ActionButton: View {
        let title: String
        let systemImage: String
        let color: Color
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack {
                    Image(systemName: systemImage)
                    Text(title)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(radius: 2)
            }
        }
    }
    
     
    struct SummaryRowView: View {
        let summaryDocument: Document
        @ObservedObject var viewModel: FolderDetailViewModel  
        var onTapAction: () -> Void  

        var body: some View {
            HStack {  
                Text(summaryDocument.name)  
                    .font(.headline)
                    .lineLimit(1)  
                Text("Saved: \(summaryDocument.creationDate.formatted(date: .abbreviated, time: .omitted))")  
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()  
                
                 
                if summaryDocument.difyConversationId != nil || ConfigManager.shared.isDifyChatConfigured {  
                    NavigationLink(destination: ConversationDashboardView(viewModel: viewModel, summaryDocument: summaryDocument)) {
                        Image(systemName: "message.fill")
                            .foregroundColor(.blue)
                            .padding(.leading, 5)
                    }
                    .buttonStyle(PlainButtonStyle())  
                }
            }
            .padding(.vertical, 4)  
            .contentShape(Rectangle())  
            .onTapGesture(perform: onTapAction)  
        }
    }
    
     
    struct FolderDetailView_Previews: PreviewProvider {
        static var previews: some View {
            let mockAPIManager = APIManager()  
            let mockDataset = KnowledgeDataset(
                id: "preview_dataset_1",
                name: "Sample Knowledge Base",
                description: "This is a sample knowledge base for preview purposes.",
                permission: "only_me",
                indexingTechnique: "high_quality",
                createdAt: Int(Date().timeIntervalSince1970)
            )
            
             
             
             
            
            return FolderDetailView(dataset: mockDataset, apiManager: mockAPIManager)
                .environmentObject(mockAPIManager)  
        }
    }
}
