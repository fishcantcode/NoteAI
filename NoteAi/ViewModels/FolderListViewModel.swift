import Foundation
import SwiftUI

class FolderListViewModel: ObservableObject {
    @Published var folders: [KnowledgeDataset] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var apiManager: APIManager

    init(apiManager: APIManager = .shared) {
        self.apiManager = apiManager
         
    }

    func loadFolders() {
        print("FolderListViewModel: loadFolders() called")
        isLoading = true
        errorMessage = nil
        folders = []  

         
        apiManager.fetchDatasets { [weak self] (result: Result<[KnowledgeDataset], APIError>) in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let datasets):
                    self?.folders = datasets
                    print("Successfully loaded \(datasets.count) folders.")
                     
                case .failure(let error):
                    self?.errorMessage = "Failed to load folders: \(error.localizedDescription)"
                    print("Error loading folders: \(error.localizedDescription)")
                }
            }
        }
    }

    func createFolder(named name: String) {
        print("FolderListViewModel: createFolder(named: \(name)) attempt.")
        isLoading = true  
        errorMessage = nil

         
        apiManager.createDataset(name: name, description: nil, indexingTechnique: "high_quality", permission: "only_me") { [weak self] (result: Result<KnowledgeDataset, APIError>) in
            DispatchQueue.main.async {
                 
                switch result {
                case .success(let newDataset):
                    print("Successfully created dataset: \(newDataset.name) with ID: \(newDataset.id)")
                     
                     
                    self?.loadFolders()  
                case .failure(let error):
                    self?.isLoading = false  
                    self?.errorMessage = "Failed to create folder: \(error.localizedDescription)"
                    print("Error creating folder: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func deleteDataset(dataset: KnowledgeDataset) {
         
         
        isLoading = true  
        errorMessage = nil

        apiManager.deleteDataset(datasetId: dataset.id) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                     
                    self?.folders.removeAll { $0.id == dataset.id }
                     
                case .failure(let error):
                    self?.errorMessage = "Failed to delete folder: \(error.localizedDescription)"
                }
            }
        }
    }
    
     
}
