import Foundation
import SwiftUI

class FolderDetailViewModel: ObservableObject {
    @ObservedObject var apiManager: APIManager
    let dataset: KnowledgeDataset

    @Published var documents: [APIDocument] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isUploadingFile: Bool = false
    @Published var uploadErrorMessage: String? = nil
    @Published var summaryFiles: [Document] = []  

    init(dataset: KnowledgeDataset, apiManager: APIManager) {
        self.dataset = dataset
        self.apiManager = apiManager
    }

    func loadDocuments() {
        print("FolderDetailViewModel: loadDocuments() called for dataset ID: \(dataset.id)")
        isLoading = true
        errorMessage = nil
        documents = []  

         
        apiManager.fetchDocuments(datasetId: dataset.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success(let fetchedDocuments):
                    self.documents = fetchedDocuments
                    print("Successfully loaded \(fetchedDocuments.count) documents for dataset: \(self.dataset.name)")
                case .failure(let error):
                    self.errorMessage = "Failed to load documents: \(error.localizedDescription)"
                    print("Error loading documents: \(error.localizedDescription) for dataset: \(self.dataset.name)")
                }
            }
        }
    }

     
    func deleteDocument(document: APIDocument) {
        isLoading = true
        errorMessage = nil
        
        apiManager.deleteDocument(datasetId: dataset.id, documentId: document.id) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.documents.removeAll { $0.id == document.id }
                     
                case .failure(let error):
                    self?.errorMessage = "Failed to delete document: \(error.localizedDescription)"
                }
            }
        }
    }

    func uploadFile(fileURL: URL) {
        print("FolderDetailViewModel: uploadFile(fileURL: \(fileURL.lastPathComponent)) called for dataset ID: \(dataset.id)")
        isUploadingFile = true
        uploadErrorMessage = nil

        apiManager.createDocumentFromFile(datasetId: dataset.id, fileURL: fileURL) { [weak self] result in
            let workItem = DispatchWorkItem {
                guard let self = self else { return }

                self.isUploadingFile = false
                switch result {
                case .success(let uploadResponse):
                    print("Successfully uploaded file: \(uploadResponse.document.name)")
                     
                     
                    let newDocument = APIDocument(
                        id: uploadResponse.document.id,
                        name: uploadResponse.document.name,
                        indexing_status: uploadResponse.document.indexing_status ?? "waiting",
                        created_at: uploadResponse.document.created_at
                    )
                    self.documents.append(newDocument)
                     
                case .failure(let error):
                    self.uploadErrorMessage = "Failed to upload file: \(error.localizedDescription)"
                    print("Error uploading file: \(error.localizedDescription)")
                }
            }
            DispatchQueue.main.async(execute: workItem)
        }
    }

     
    func createDocument(name: String, content: String) {
        print("FolderDetailViewModel: createDocument(name: \(name)) called - placeholder for API integration")
         
         
         
    }

     
    func loadSummaryFiles() {
        print("FolderDetailViewModel: loadSummaryFiles() called")
         
         
        DispatchQueue.global(qos: .userInitiated).async {
            let files = DocumentManager.shared.loadSummaryFiles()
            DispatchQueue.main.async {
                self.summaryFiles = files
                print("FolderDetailViewModel: Loaded \(files.count) summary files.")

                 
                print("--- Saved Summaries Content ---")
                for summaryDoc in self.summaryFiles {
                    if let content = self.getSummaryContent(for: summaryDoc) {
                        print("File: \(summaryDoc.name)")
                        print("Content:\n\(content)")
                        print("-------------------------------")
                    } else {
                        print("File: \(summaryDoc.name) - Error: Could not read content.")
                        print("-------------------------------")
                    }
                }
            }
        }
    }

    func getSummaryContent(for document: Document) -> String? {
        print("FolderDetailViewModel: getSummaryContent(for: \(document.name)) called")
        do {
            let content = try String(contentsOf: document.url, encoding: .utf8)
            print("Successfully read content from \(document.url.path)")
            return content
        } catch {
            print("FolderDetailViewModel: Error reading content from \(document.url.path): \(error.localizedDescription)")
            return nil
        }
    }

     
    func deleteLocalSummary(summaryDocument: Document) {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            self.errorMessage = "Could not access documents directory."
            return
        }
         
         
        let fileName = "summary_\(summaryDocument.id).json"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
                 
                DispatchQueue.main.async {
                    self.summaryFiles.removeAll { $0.id == summaryDocument.id }
                    print("Successfully deleted summary: \(fileName)")
                }
            } else {
                self.errorMessage = "Summary file not found for deletion: \(fileName)"
                 
                DispatchQueue.main.async {
                    self.summaryFiles.removeAll { $0.id == summaryDocument.id }
                }
            }
        } catch {
            self.errorMessage = "Failed to delete summary \(fileName): \(error.localizedDescription)"
            print("Error deleting summary \(fileName): \(error.localizedDescription)")
        }
    }

     
    func saveDifyConversationId(for document: Document, difyId: String) {
        DispatchQueue.main.async {
            if let index = self.summaryFiles.firstIndex(where: { $0.id == document.id }) {
                self.summaryFiles[index].difyConversationId = difyId
                print("DEBUG: Updated difyConversationId for document '\(document.name)' to '\(difyId)'.")
                
                 
                 
                 
                 
                
                 
                 
                
                 
                 
            } else {
                print("ERROR: Could not find document with ID \(document.id) to save difyConversationId.")
            }
        }
    }

     
    func saveSummaryToFile(summary: String, forDocumentId: String, withName: String) {
         
    }
}
