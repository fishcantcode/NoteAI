import Foundation

class DocumentManager {
    static let shared = DocumentManager()
    private let fileManager = FileManager.default
    private let baseURL: URL

    private init() {
        baseURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("VT6001CEM")
        setupFileSystem()
    }

    func setupFileSystem() {
        if !fileManager.fileExists(atPath: baseURL.path) {
            do {
                try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
                print("DocumentManager: Created base directory at \(baseURL.path)")
            } catch {
                print("DocumentManager: Error creating base directory: \(error.localizedDescription)")
            }
        }
    }

    func createFolder(named name: String) {
        let newFolderURL = baseURL.appendingPathComponent(name)
        if !fileManager.fileExists(atPath: newFolderURL.path) {
            do {
                try fileManager.createDirectory(at: newFolderURL, withIntermediateDirectories: true)
                print("DocumentManager: Created folder '\(name)' at \(newFolderURL.path)")
            } catch {
                print("DocumentManager: Error creating folder '\(name)': \(error.localizedDescription)")
            }
        } else {
            print("DocumentManager: Folder '\(name)' already exists.")
        }
    }

    func loadFolders() -> [Document] {
        var documents: [Document] = []
        do {
            let contents = try fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey, .nameKey], options: .skipsHiddenFiles)
            
            for itemURL in contents {
                let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey, .creationDateKey, .nameKey])
                if resourceValues.isDirectory == true {
                    let creationDate = resourceValues.creationDate ?? Date.distantPast
                    let name = resourceValues.name ?? itemURL.lastPathComponent
                    let document = Document(id: UUID(), name: name, type: .folder, creationDate: creationDate, url: itemURL)
                    documents.append(document)
                }
            }
        } catch {
            print("DocumentManager: Error loading folders: \(error.localizedDescription)")
        }
        return documents
    }

    func fileCount(in folderURL: URL) -> Int {
        do {
            let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
            let filesOnly = contents.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == false }
            return filesOnly.count
        } catch {
            print("DocumentManager: Error counting files in \(folderURL.path): \(error.localizedDescription)")
            return 0
        }
    }

    func saveTextToFile(content: String, fileName: String) throws {
        let fileURL = baseURL.appendingPathComponent(fileName)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("DocumentManager: Successfully saved text to \(fileURL.path)")
        } catch {
            print("DocumentManager: Error saving text to file \(fileName): \(error.localizedDescription)")
            throw error  
        }
    }

    func loadSummaryFiles() -> [Document] {
        var summaryDocuments: [Document] = []
        do {
            let contents = try fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey, .nameKey], options: .skipsHiddenFiles)
            
            for itemURL in contents {
                let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey, .creationDateKey, .nameKey])
                 
                if resourceValues.isDirectory == false && itemURL.pathExtension.lowercased() == "txt" {
                    let creationDate = resourceValues.creationDate ?? Date.distantPast
                    let name = resourceValues.name ?? itemURL.lastPathComponent
                     
                    let document = Document(id: UUID(), name: name, type: .file, creationDate: creationDate, url: itemURL)  
                    summaryDocuments.append(document)
                }
            }
        } catch {
            print("DocumentManager: Error loading summary files: \(error.localizedDescription)")
        }
         
        return summaryDocuments.sorted(by: { $0.creationDate > $1.creationDate })
    }

    func readTextFromFile(fileName: String) throws -> String {
        let fileURL = baseURL.appendingPathComponent(fileName)
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            print("DocumentManager: Successfully read text from \(fileURL.path)")
            return content
        } catch {
            print("DocumentManager: Error reading text from file \(fileName): \(error.localizedDescription)")
            throw error
        }
    }
}
